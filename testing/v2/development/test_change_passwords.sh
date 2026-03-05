#!/bin/bash

# test_change_passwords.sh
#
# Tests the change_passwords.yml Ansible playbook in the Docker cluster
# environment. Run from the HOST machine while the cluster containers are up.
#
# Prerequisites:
#   1. Start cluster:   docker compose -f docker-compose-cluster.yml up -d --build
#   2. Install cluster: bash install_cluster.sh
#   3. Run this test:   bash test_change_passwords.sh
#
# Options:
#   -d, --debug   Enable verbose Ansible output
#   -h, --help    Show help

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

MASTER_CONTAINER="lme_2404_cluster_node1"
NODE2_CONTAINER="lme_2404_cluster_node2"
NODE3_CONTAINER="lme_2404_cluster_node3"

TEST_PASSWORD="ChangeMe_Test_Pwd_99!"
ANSIBLE_OPTS=""
TESTS_PASSED=0
TESTS_FAILED=0

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--debug)
            ANSIBLE_OPTS="-e lme_debug=true -v"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "OPTIONS:"
            echo "  -d, --debug   Enable verbose Ansible output"
            echo "  -h, --help    Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Helper: run command in container as root
docker_exec() {
    local container=$1
    shift
    docker exec "$container" bash -c "$*"
}

# Helper: run command as lme-user
docker_exec_as_lme_user() {
    local container=$1
    shift
    docker exec -u lme-user "$container" bash -c "$*"
}

# Helper: record test result
pass() {
    echo -e "  ${GREEN}PASS${NC}: $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
    echo -e "  ${RED}FAIL${NC}: $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

# =========================================================================
# Pre-flight checks
# =========================================================================
echo -e "${YELLOW}=== Pre-flight Checks ===${NC}"

for container in "$MASTER_CONTAINER" "$NODE2_CONTAINER" "$NODE3_CONTAINER"; do
    if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        echo -e "${RED}Container $container is not running.${NC}"
        echo "Start the cluster first: docker compose -f docker-compose-cluster.yml up -d --build"
        echo "Then install:            bash install_cluster.sh"
        exit 1
    fi
done
echo -e "  ${GREEN}All containers running${NC}"

# =========================================================================
# Step 1: Get the current elastic password from master
# =========================================================================
echo ""
echo -e "${YELLOW}Step 1: Reading current elastic password from master${NC}"

ORIGINAL_PASSWORD=$(docker_exec "$MASTER_CONTAINER" '
    export PATH=$PATH:/nix/var/nix/profiles/default/bin
    export ANSIBLE_VAULT_PASSWORD_FILE=/etc/lme/pass.sh
    ELASTIC_ID=$(podman secret ls --noheading | awk "\$2 == \"elastic\" { print \$1 }")
    ansible-vault view /etc/lme/vault/$ELASTIC_ID 2>/dev/null | tr -d "\n"
')

if [ -z "$ORIGINAL_PASSWORD" ]; then
    echo -e "${RED}Could not read current elastic password. Is the cluster fully installed?${NC}"
    exit 1
fi
echo "  Current password length: ${#ORIGINAL_PASSWORD}"

# =========================================================================
# Step 2: Verify current password works on master ES
# =========================================================================
echo ""
echo -e "${YELLOW}Step 2: Verifying current password works on master${NC}"

HTTP_CODE=$(docker_exec "$MASTER_CONTAINER" \
    "curl -sk -o /dev/null -w '%{http_code}' -u 'elastic:${ORIGINAL_PASSWORD}' https://localhost:9200/_cluster/health")

if [ "$HTTP_CODE" = "200" ]; then
    pass "Current password authenticates on master (HTTP 200)"
else
    fail "Current password returned HTTP $HTTP_CODE on master"
    echo -e "${RED}Cannot proceed without working credentials.${NC}"
    exit 1
fi

# =========================================================================
# Step 3: Run the password change playbook
# =========================================================================
echo ""
echo -e "${YELLOW}Step 3: Running change_passwords.yml (elastic -> test password)${NC}"

docker_exec_as_lme_user "$MASTER_CONTAINER" "
    cd ~/LME && \
    ANSIBLE_LOCAL_TEMP=/tmp/ansible-tmp \
    ANSIBLE_REMOTE_TEMP=/tmp/ansible-tmp \
    ansible-playbook -i ansible/inventory/cluster.yml ansible/change_passwords.yml \
        -e lme_user=elastic \
        -e lme_password='${TEST_PASSWORD}' \
        ${ANSIBLE_OPTS}
"
echo -e "  ${GREEN}Playbook completed${NC}"

# =========================================================================
# Step 4: Verify new password works on master
# =========================================================================
echo ""
echo -e "${YELLOW}Step 4: Verifying new password works on master${NC}"

HTTP_CODE=$(docker_exec "$MASTER_CONTAINER" \
    "curl -sk -o /dev/null -w '%{http_code}' -u 'elastic:${TEST_PASSWORD}' https://localhost:9200/_cluster/health")

if [ "$HTTP_CODE" = "200" ]; then
    pass "New password authenticates on master (HTTP 200)"
else
    fail "New password returned HTTP $HTTP_CODE on master"
fi

# =========================================================================
# Step 5: Verify old password no longer works
# =========================================================================
echo ""
echo -e "${YELLOW}Step 5: Verifying old password is rejected${NC}"

HTTP_CODE=$(docker_exec "$MASTER_CONTAINER" \
    "curl -sk -o /dev/null -w '%{http_code}' -u 'elastic:${ORIGINAL_PASSWORD}' https://localhost:9200/_cluster/health")

if [ "$HTTP_CODE" = "401" ]; then
    pass "Old password correctly rejected (HTTP 401)"
elif [ "$HTTP_CODE" = "200" ]; then
    fail "Old password still works (HTTP 200) -- password was not changed"
else
    pass "Old password rejected (HTTP $HTTP_CODE)"
fi

# =========================================================================
# Step 6: Verify secrets were distributed to node2 and node3
# =========================================================================
echo ""
echo -e "${YELLOW}Step 6: Verifying secrets on cluster nodes${NC}"

for node_container in "$NODE2_CONTAINER" "$NODE3_CONTAINER"; do
    NODE_PASSWORD=$(docker_exec "$node_container" '
        export PATH=$PATH:/nix/var/nix/profiles/default/bin
        export ANSIBLE_VAULT_PASSWORD_FILE=/etc/lme/pass.sh
        ELASTIC_ID=$(podman secret ls --noheading | awk "\$2 == \"elastic\" { print \$1 }")
        if [ -n "$ELASTIC_ID" ] && [ -f "/etc/lme/vault/$ELASTIC_ID" ]; then
            ansible-vault view /etc/lme/vault/$ELASTIC_ID 2>/dev/null | tr -d "\n"
        fi
    ')

    if [ "$NODE_PASSWORD" = "$TEST_PASSWORD" ]; then
        pass "Secret on $node_container matches new password"
    else
        fail "Secret on $node_container does not match (got length ${#NODE_PASSWORD})"
    fi
done

# =========================================================================
# Step 7: Verify cluster health
# =========================================================================
echo ""
echo -e "${YELLOW}Step 7: Checking cluster health${NC}"

HEALTH_JSON=$(docker_exec "$MASTER_CONTAINER" \
    "curl -sk -u 'elastic:${TEST_PASSWORD}' https://localhost:9200/_cluster/health?pretty")

HEALTH_STATUS=$(echo "$HEALTH_JSON" | grep '"status"' | sed 's/.*: "\(.*\)".*/\1/')
NODE_COUNT=$(echo "$HEALTH_JSON" | grep '"number_of_nodes"' | sed 's/[^0-9]//g')

echo "  Status: $HEALTH_STATUS"
echo "  Nodes:  $NODE_COUNT"

if [ "$HEALTH_STATUS" = "green" ] || [ "$HEALTH_STATUS" = "yellow" ]; then
    pass "Cluster is healthy ($HEALTH_STATUS)"
else
    fail "Cluster health is $HEALTH_STATUS"
fi

if [ "$NODE_COUNT" -ge 3 ] 2>/dev/null; then
    pass "All 3 nodes present"
else
    fail "Expected 3 nodes, got ${NODE_COUNT:-unknown}"
fi

# =========================================================================
# Step 8: Restore original password
# =========================================================================
echo ""
echo -e "${YELLOW}Step 8: Restoring original elastic password${NC}"

docker_exec_as_lme_user "$MASTER_CONTAINER" "
    cd ~/LME && \
    ANSIBLE_LOCAL_TEMP=/tmp/ansible-tmp \
    ANSIBLE_REMOTE_TEMP=/tmp/ansible-tmp \
    ansible-playbook -i ansible/inventory/cluster.yml ansible/change_passwords.yml \
        -e lme_user=elastic \
        -e lme_password='${ORIGINAL_PASSWORD}' \
        ${ANSIBLE_OPTS}
"

# Verify restore worked
HTTP_CODE=$(docker_exec "$MASTER_CONTAINER" \
    "curl -sk -o /dev/null -w '%{http_code}' -u 'elastic:${ORIGINAL_PASSWORD}' https://localhost:9200/_cluster/health")

if [ "$HTTP_CODE" = "200" ]; then
    pass "Original password restored successfully"
else
    fail "Original password restore failed (HTTP $HTTP_CODE)"
fi

# =========================================================================
# Summary
# =========================================================================
echo ""
echo "============================================"
echo "  Test Summary"
echo "============================================"
echo -e "  Passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "  Failed: ${RED}${TESTS_FAILED}${NC}"
echo ""

if [ "$TESTS_FAILED" -gt 0 ]; then
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed.${NC}"
    exit 0
fi
