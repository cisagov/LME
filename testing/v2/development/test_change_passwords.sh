#!/bin/bash

# test_change_passwords.sh
#
# Tests the change_passwords.yml Ansible playbook in the Docker cluster
# environment. Run from the HOST machine while the cluster containers are up.
#
# Tests all supported users: elastic, kibana_system, wazuh, wazuh_api
#
# Prerequisites:
#   1. Start cluster:   docker compose -f docker-compose-cluster.yml up -d --build
#   2. Install cluster: bash install_cluster.sh
#   3. Run this test:   bash test_change_passwords.sh
#
# Options:
#   -d, --debug                Enable verbose Ansible output
#   -f, --compose-file FILE    Docker compose file for container name extraction
#   -h, --help                 Show help

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

MASTER_CONTAINER="lme_cluster_node1"
NODE2_CONTAINER="lme_cluster_node2"
NODE3_CONTAINER="lme_cluster_node3"

ELASTIC_TEST_PASSWORD="ChangeMe_Test_Pwd_99.X"
WAZUH_TEST_PASSWORD="WazuhTest.Pass_789"
ANSIBLE_OPTS=""
TESTS_PASSED=0
TESTS_FAILED=0
COMPOSE_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--debug)
            ANSIBLE_OPTS="-e lme_debug=true -v"
            shift
            ;;
        -f|--compose-file)
            COMPOSE_FILE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "OPTIONS:"
            echo "  -d, --debug                Enable verbose Ansible output"
            echo "  -f, --compose-file FILE    Docker compose file for container name extraction"
            echo "  -h, --help                 Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# =========================================================================
# Extract container names from compose file if provided
# =========================================================================
if [ -n "$COMPOSE_FILE" ]; then
    if [ ! -f "$COMPOSE_FILE" ]; then
        echo -e "${RED}Compose file not found: $COMPOSE_FILE${NC}"
        exit 1
    fi
    NAMES=$(grep 'container_name:' "$COMPOSE_FILE" | awk '{print $2}')
    NODE1_NAME=$(echo "$NAMES" | grep 'node1' || true)
    NODE2_NAME=$(echo "$NAMES" | grep 'node2' || true)
    NODE3_NAME=$(echo "$NAMES" | grep 'node3' || true)
    if [ -n "$NODE1_NAME" ] && [ -n "$NODE2_NAME" ] && [ -n "$NODE3_NAME" ]; then
        MASTER_CONTAINER="$NODE1_NAME"
        NODE2_CONTAINER="$NODE2_NAME"
        NODE3_CONTAINER="$NODE3_NAME"
        echo -e "${GREEN}Extracted container names from $COMPOSE_FILE:${NC}"
        echo "  Master: $MASTER_CONTAINER"
        echo "  Node2:  $NODE2_CONTAINER"
        echo "  Node3:  $NODE3_CONTAINER"
    else
        echo -e "${YELLOW}Could not extract all node names from $COMPOSE_FILE, using defaults${NC}"
    fi
fi

# =========================================================================
# Helper functions
# =========================================================================

# Run command in container as root
docker_exec() {
    local container=$1
    shift
    docker exec "$container" bash -c "$*"
}

# Run command in container as root with a TTY (needed by expect scripts)
docker_exec_tty() {
    local container=$1
    shift
    docker exec -t "$container" bash -c "$*"
}

# Run command as lme-user
docker_exec_as_lme_user() {
    local container=$1
    shift
    docker exec -u lme-user "$container" bash -c "$*"
}

# Record test result
pass() {
    echo -e "  ${GREEN}PASS${NC}: $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
    echo -e "  ${RED}FAIL${NC}: $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

# Read a secret from a container's vault by secret name
read_vault_secret() {
    local container=$1
    local secret_name=$2
    docker_exec "$container" "
        export PATH=\$PATH:/nix/var/nix/profiles/default/bin
        export ANSIBLE_VAULT_PASSWORD_FILE=/etc/lme/pass.sh
        SECRET_ID=\$(podman secret ls --noheading | awk '\$2 == \"${secret_name}\" { print \$1 }')
        if [ -n \"\$SECRET_ID\" ] && [ -f \"/etc/lme/vault/\$SECRET_ID\" ]; then
            ansible-vault view /etc/lme/vault/\$SECRET_ID 2>/dev/null | tr -d '\n'
        fi
    "
}

# Run the change_passwords playbook
run_change_password() {
    local user=$1
    local password=$2
    docker_exec_as_lme_user "$MASTER_CONTAINER" "
        cd ~/LME && \
        ANSIBLE_LOCAL_TEMP=/tmp/ansible-tmp \
        ANSIBLE_REMOTE_TEMP=/tmp/ansible-tmp \
        ansible-playbook -i ansible/inventory/cluster.yml ansible/change_passwords.yml \
            -e lme_user=${user} \
            -e lme_password='${password}' \
            ${ANSIBLE_OPTS}
    "
}

# Verify ES cluster health using elastic credentials
verify_cluster_health() {
    local elastic_pw=$1
    local health_json
    health_json=$(docker_exec "$MASTER_CONTAINER" \
        "curl -sk -u 'elastic:${elastic_pw}' https://localhost:9200/_cluster/health?pretty")

    local health_status
    health_status=$(echo "$health_json" | grep '"status"' | sed 's/.*: "\(.*\)".*/\1/')
    local node_count
    node_count=$(echo "$health_json" | grep '"number_of_nodes"' | sed 's/[^0-9]//g')

    echo "  Status: $health_status"
    echo "  Nodes:  $node_count"

    if [ "$health_status" = "green" ] || [ "$health_status" = "yellow" ]; then
        pass "Cluster is healthy ($health_status)"
    else
        fail "Cluster health is $health_status"
    fi

    if [ "$node_count" -ge 3 ] 2>/dev/null; then
        pass "All 3 nodes present"
    else
        fail "Expected 3 nodes, got ${node_count:-unknown}"
    fi
}

# Wait for Wazuh daemons to be ready inside the master container
wait_for_wazuh() {
    echo "  Waiting for Wazuh daemons to be ready..."
    local retries=30
    local delay=10
    for i in $(seq 1 $retries); do
        local output
        output=$(docker_exec "$MASTER_CONTAINER" "
            podman exec lme-wazuh-manager /var/ossec/bin/wazuh-control status 2>&1
        " 2>/dev/null || true)

        local all_ready=true
        for daemon in wazuh-modulesd wazuh-analysisd wazuh-execd wazuh-db wazuh-remoted wazuh-apid; do
            if echo "$output" | grep -q "$daemon not running"; then
                all_ready=false
                break
            fi
        done

        if $all_ready && echo "$output" | grep -q "is running"; then
            echo -e "  ${GREEN}Wazuh daemons ready${NC}"
            return 0
        fi

        if [ "$i" -lt "$retries" ]; then
            echo "  Attempt $i/$retries: Wazuh not ready yet, waiting ${delay}s..."
            sleep "$delay"
        fi
    done
    echo -e "  ${YELLOW}WARNING: Wazuh daemons may not be fully ready after ${retries} attempts${NC}"
    return 1
}

# Verify Wazuh API is responding (401 = up and healthy, just unauthenticated)
verify_wazuh_api() {
    local http_code
    http_code=$(docker_exec "$MASTER_CONTAINER" \
        "curl -sk -o /dev/null -w '%{http_code}' https://localhost:55000/")
    if [ "$http_code" = "401" ] || [ "$http_code" = "200" ]; then
        pass "Wazuh API is responding (HTTP $http_code)"
    else
        fail "Wazuh API returned HTTP $http_code (expected 401 or 200)"
    fi
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

# Get current elastic password for use in health checks throughout
CURRENT_ELASTIC_PW=$(read_vault_secret "$MASTER_CONTAINER" "elastic")
if [ -z "$CURRENT_ELASTIC_PW" ]; then
    echo -e "${RED}Could not read current elastic password. Is the cluster fully installed?${NC}"
    exit 1
fi

# =========================================================================
# Test 1: elastic password change
# =========================================================================
test_elastic() {
    echo ""
    echo -e "${YELLOW}=== Test: elastic password change ===${NC}"

    local original_pw
    original_pw=$(read_vault_secret "$MASTER_CONTAINER" "elastic")
    if [ -z "$original_pw" ]; then
        fail "Could not read current elastic password"
        return
    fi
    echo "  Current password length: ${#original_pw}"

    # Verify current password works
    local http_code
    http_code=$(docker_exec "$MASTER_CONTAINER" \
        "curl -sk -o /dev/null -w '%{http_code}' -u 'elastic:${original_pw}' https://localhost:9200/_cluster/health")
    if [ "$http_code" = "200" ]; then
        pass "Current password authenticates on master (HTTP 200)"
    else
        fail "Current password returned HTTP $http_code on master"
        return
    fi

    # Change password
    echo "  Running change_passwords.yml (elastic -> test password)..."
    run_change_password "elastic" "$ELASTIC_TEST_PASSWORD"
    echo -e "  ${GREEN}Playbook completed${NC}"

    # Verify new password works
    http_code=$(docker_exec "$MASTER_CONTAINER" \
        "curl -sk -o /dev/null -w '%{http_code}' -u 'elastic:${ELASTIC_TEST_PASSWORD}' https://localhost:9200/_cluster/health")
    if [ "$http_code" = "200" ]; then
        pass "New password authenticates on master (HTTP 200)"
    else
        fail "New password returned HTTP $http_code on master"
    fi

    # Verify old password rejected
    http_code=$(docker_exec "$MASTER_CONTAINER" \
        "curl -sk -o /dev/null -w '%{http_code}' -u 'elastic:${original_pw}' https://localhost:9200/_cluster/health")
    if [ "$http_code" = "401" ]; then
        pass "Old password correctly rejected (HTTP 401)"
    elif [ "$http_code" = "200" ]; then
        fail "Old password still works (HTTP 200) -- password was not changed"
    else
        pass "Old password rejected (HTTP $http_code)"
    fi

    # Verify secrets on cluster nodes
    echo "  Verifying secrets on cluster nodes..."
    for node_container in "$NODE2_CONTAINER" "$NODE3_CONTAINER"; do
        local node_pw
        node_pw=$(read_vault_secret "$node_container" "elastic")
        if [ "$node_pw" = "$ELASTIC_TEST_PASSWORD" ]; then
            pass "Secret on $node_container matches new password"
        else
            fail "Secret on $node_container does not match (got length ${#node_pw})"
        fi
    done

    # Verify cluster health
    echo "  Checking cluster health..."
    verify_cluster_health "$ELASTIC_TEST_PASSWORD"

    # Restore original password
    echo "  Restoring original elastic password..."
    run_change_password "elastic" "$original_pw"

    http_code=$(docker_exec "$MASTER_CONTAINER" \
        "curl -sk -o /dev/null -w '%{http_code}' -u 'elastic:${original_pw}' https://localhost:9200/_cluster/health")
    if [ "$http_code" = "200" ]; then
        pass "Original password restored successfully"
    else
        fail "Original password restore failed (HTTP $http_code)"
    fi

    # Update the elastic password tracker for subsequent tests
    CURRENT_ELASTIC_PW="$original_pw"
}

# =========================================================================
# Test 2: kibana_system password change
# =========================================================================
test_kibana_system() {
    echo ""
    echo -e "${YELLOW}=== Test: kibana_system password change ===${NC}"

    local original_pw
    original_pw=$(read_vault_secret "$MASTER_CONTAINER" "kibana_system")
    if [ -z "$original_pw" ]; then
        fail "Could not read current kibana_system password"
        return
    fi
    echo "  Current password length: ${#original_pw}"

    # Change password
    echo "  Running change_passwords.yml (kibana_system -> test password)..."
    run_change_password "kibana_system" "$ELASTIC_TEST_PASSWORD"
    echo -e "  ${GREEN}Playbook completed${NC}"

    # Verify vault secret updated on master
    local new_pw
    new_pw=$(read_vault_secret "$MASTER_CONTAINER" "kibana_system")
    if [ "$new_pw" = "$ELASTIC_TEST_PASSWORD" ]; then
        pass "Vault secret updated on master"
    else
        fail "Vault secret on master does not match new password"
    fi

    # Verify cluster health (Kibana was restarted by the playbook)
    echo "  Checking cluster health after Kibana restart..."
    verify_cluster_health "$CURRENT_ELASTIC_PW"

    # Restore original password
    echo "  Restoring original kibana_system password..."
    run_change_password "kibana_system" "$original_pw"

    local restored_pw
    restored_pw=$(read_vault_secret "$MASTER_CONTAINER" "kibana_system")
    if [ "$restored_pw" = "$original_pw" ]; then
        pass "Original kibana_system password restored successfully"
    else
        fail "kibana_system password restore failed"
    fi
}

# =========================================================================
# Test 3: wazuh password change
# =========================================================================
test_wazuh() {
    echo ""
    echo -e "${YELLOW}=== Test: wazuh password change ===${NC}"

    # Save original passwords (both wazuh and wazuh_api are changed together)
    local original_wazuh_pw
    original_wazuh_pw=$(read_vault_secret "$MASTER_CONTAINER" "wazuh")
    local original_wazuh_api_pw
    original_wazuh_api_pw=$(read_vault_secret "$MASTER_CONTAINER" "wazuh_api")

    if [ -z "$original_wazuh_pw" ] || [ -z "$original_wazuh_api_pw" ]; then
        fail "Could not read current wazuh/wazuh_api passwords"
        return
    fi
    echo "  Current wazuh password length: ${#original_wazuh_pw}"
    echo "  Current wazuh_api password length: ${#original_wazuh_api_pw}"

    # Wait for Wazuh to be ready before changing
    wait_for_wazuh || true

    # Change password
    echo "  Running change_passwords.yml (wazuh -> test password)..."
    run_change_password "wazuh" "$WAZUH_TEST_PASSWORD"
    echo -e "  ${GREEN}Playbook completed${NC}"

    # Verify both vault secrets updated on master
    local new_wazuh_pw
    new_wazuh_pw=$(read_vault_secret "$MASTER_CONTAINER" "wazuh")
    if [ "$new_wazuh_pw" = "$WAZUH_TEST_PASSWORD" ]; then
        pass "Wazuh vault secret updated on master"
    else
        fail "Wazuh vault secret on master does not match new password"
    fi

    local new_wazuh_api_pw
    new_wazuh_api_pw=$(read_vault_secret "$MASTER_CONTAINER" "wazuh_api")
    if [ "$new_wazuh_api_pw" = "$WAZUH_TEST_PASSWORD" ]; then
        pass "Wazuh_api vault secret also updated on master (paired update)"
    else
        fail "Wazuh_api vault secret was not updated on master"
    fi

    # Wait for Wazuh to come back up after restart
    wait_for_wazuh || true

    # Verify Wazuh API is responding
    verify_wazuh_api

    # Restore original passwords
    echo "  Restoring original wazuh password..."
    run_change_password "wazuh" "$original_wazuh_pw"

    local restored_wazuh_pw
    restored_wazuh_pw=$(read_vault_secret "$MASTER_CONTAINER" "wazuh")
    local restored_wazuh_api_pw
    restored_wazuh_api_pw=$(read_vault_secret "$MASTER_CONTAINER" "wazuh_api")

    if [ "$restored_wazuh_pw" = "$original_wazuh_pw" ]; then
        pass "Original wazuh password restored"
    else
        fail "Wazuh password restore failed"
    fi

    if [ "$restored_wazuh_api_pw" = "$original_wazuh_pw" ]; then
        pass "Wazuh_api password restored (paired with wazuh)"
    else
        fail "Wazuh_api password restore failed"
    fi

    # Wait for Wazuh to stabilize after restore
    wait_for_wazuh || true
}

# =========================================================================
# Test 4: wazuh_api password change
# =========================================================================
test_wazuh_api() {
    echo ""
    echo -e "${YELLOW}=== Test: wazuh_api password change ===${NC}"

    # Save original passwords
    local original_wazuh_pw
    original_wazuh_pw=$(read_vault_secret "$MASTER_CONTAINER" "wazuh")
    local original_wazuh_api_pw
    original_wazuh_api_pw=$(read_vault_secret "$MASTER_CONTAINER" "wazuh_api")

    if [ -z "$original_wazuh_pw" ] || [ -z "$original_wazuh_api_pw" ]; then
        fail "Could not read current wazuh/wazuh_api passwords"
        return
    fi
    echo "  Current wazuh password length: ${#original_wazuh_pw}"
    echo "  Current wazuh_api password length: ${#original_wazuh_api_pw}"

    # Wait for Wazuh to be ready before changing
    wait_for_wazuh || true

    # Change password
    echo "  Running change_passwords.yml (wazuh_api -> test password)..."
    run_change_password "wazuh_api" "$WAZUH_TEST_PASSWORD"
    echo -e "  ${GREEN}Playbook completed${NC}"

    # Verify both vault secrets updated on master
    local new_wazuh_api_pw
    new_wazuh_api_pw=$(read_vault_secret "$MASTER_CONTAINER" "wazuh_api")
    if [ "$new_wazuh_api_pw" = "$WAZUH_TEST_PASSWORD" ]; then
        pass "Wazuh_api vault secret updated on master"
    else
        fail "Wazuh_api vault secret on master does not match new password"
    fi

    local new_wazuh_pw
    new_wazuh_pw=$(read_vault_secret "$MASTER_CONTAINER" "wazuh")
    if [ "$new_wazuh_pw" = "$WAZUH_TEST_PASSWORD" ]; then
        pass "Wazuh vault secret also updated on master (paired update)"
    else
        fail "Wazuh vault secret was not updated on master"
    fi

    # Wait for Wazuh to come back up after restart
    wait_for_wazuh || true

    # Verify Wazuh API is responding
    verify_wazuh_api

    # Restore original passwords
    echo "  Restoring original wazuh_api password..."
    run_change_password "wazuh_api" "$original_wazuh_api_pw"

    local restored_wazuh_pw
    restored_wazuh_pw=$(read_vault_secret "$MASTER_CONTAINER" "wazuh")
    local restored_wazuh_api_pw
    restored_wazuh_api_pw=$(read_vault_secret "$MASTER_CONTAINER" "wazuh_api")

    if [ "$restored_wazuh_api_pw" = "$original_wazuh_api_pw" ]; then
        pass "Original wazuh_api password restored"
    else
        fail "Wazuh_api password restore failed"
    fi

    if [ "$restored_wazuh_pw" = "$original_wazuh_api_pw" ]; then
        pass "Wazuh password restored (paired with wazuh_api)"
    else
        fail "Wazuh password restore failed"
    fi

    # Wait for Wazuh to stabilize after restore
    wait_for_wazuh || true
}

# =========================================================================
# Test 5: password_management.sh — reset_elastic_password.exp (elastic)
# =========================================================================
test_script_elastic() {
    echo ""
    echo -e "${YELLOW}=== Test: password_management.sh / reset_elastic_password.exp (elastic) ===${NC}"

    local original_pw
    original_pw=$(read_vault_secret "$MASTER_CONTAINER" "elastic")
    if [ -z "$original_pw" ]; then
        fail "Could not read current elastic password"
        return
    fi

    local test_pw="ScriptTest.Pwd_42ab"

    # Change via expect script (needs TTY for podman exec -it inside)
    echo "  Changing elastic password via reset_elastic_password.exp..."
    docker_exec_tty "$MASTER_CONTAINER" "
        export PATH=\$PATH:/nix/var/nix/profiles/default/bin
        export ANSIBLE_VAULT_PASSWORD_FILE=/etc/lme/pass.sh
        cd /home/lme-user/LME/scripts
        ./reset_elastic_password.exp elastic '${test_pw}'
    "
    local rc=$?
    if [ "$rc" -eq 0 ]; then
        pass "reset_elastic_password.exp exited 0"
    else
        fail "reset_elastic_password.exp exited $rc"
    fi

    # Verify new password works
    local http_code
    http_code=$(docker_exec "$MASTER_CONTAINER" \
        "curl -sk -o /dev/null -w '%{http_code}' -u 'elastic:${test_pw}' https://localhost:9200/_cluster/health")
    if [ "$http_code" = "200" ]; then
        pass "New password authenticates via ES API (HTTP 200)"
    else
        fail "New password returned HTTP $http_code (expected 200)"
    fi

    # Verify old password rejected
    http_code=$(docker_exec "$MASTER_CONTAINER" \
        "curl -sk -o /dev/null -w '%{http_code}' -u 'elastic:${original_pw}' https://localhost:9200/_cluster/health")
    if [ "$http_code" = "401" ]; then
        pass "Old password correctly rejected (HTTP 401)"
    else
        fail "Old password returned HTTP $http_code (expected 401)"
    fi

    # Restore via expect script
    echo "  Restoring elastic password via reset_elastic_password.exp..."
    docker_exec_tty "$MASTER_CONTAINER" "
        export PATH=\$PATH:/nix/var/nix/profiles/default/bin
        export ANSIBLE_VAULT_PASSWORD_FILE=/etc/lme/pass.sh
        cd /home/lme-user/LME/scripts
        ./reset_elastic_password.exp elastic '${original_pw}'
    "

    http_code=$(docker_exec "$MASTER_CONTAINER" \
        "curl -sk -o /dev/null -w '%{http_code}' -u 'elastic:${original_pw}' https://localhost:9200/_cluster/health")
    if [ "$http_code" = "200" ]; then
        pass "Original elastic password restored via expect script"
    else
        fail "Elastic password restore via expect failed (HTTP $http_code)"
    fi
}

# =========================================================================
# Test 6: password_management.sh — reset_elastic_password.exp (kibana_system)
# =========================================================================
test_script_kibana_system() {
    echo ""
    echo -e "${YELLOW}=== Test: password_management.sh / reset_elastic_password.exp (kibana_system) ===${NC}"

    local original_pw
    original_pw=$(read_vault_secret "$MASTER_CONTAINER" "kibana_system")
    if [ -z "$original_pw" ]; then
        fail "Could not read current kibana_system password"
        return
    fi

    local test_pw="KibanaScript.Test_42"

    echo "  Changing kibana_system password via reset_elastic_password.exp..."
    docker_exec_tty "$MASTER_CONTAINER" "
        export PATH=\$PATH:/nix/var/nix/profiles/default/bin
        export ANSIBLE_VAULT_PASSWORD_FILE=/etc/lme/pass.sh
        cd /home/lme-user/LME/scripts
        ./reset_elastic_password.exp kibana_system '${test_pw}'
    "
    local rc=$?
    if [ "$rc" -eq 0 ]; then
        pass "reset_elastic_password.exp exited 0 for kibana_system"
    else
        fail "reset_elastic_password.exp exited $rc for kibana_system"
    fi

    # Verify new password works (kibana_system can auth to ES)
    local http_code
    http_code=$(docker_exec "$MASTER_CONTAINER" \
        "curl -sk -o /dev/null -w '%{http_code}' -u 'kibana_system:${test_pw}' https://localhost:9200/")
    if [ "$http_code" = "200" ]; then
        pass "New kibana_system password authenticates (HTTP 200)"
    else
        fail "New kibana_system password returned HTTP $http_code (expected 200)"
    fi

    # Restore
    echo "  Restoring kibana_system password via reset_elastic_password.exp..."
    docker_exec_tty "$MASTER_CONTAINER" "
        export PATH=\$PATH:/nix/var/nix/profiles/default/bin
        export ANSIBLE_VAULT_PASSWORD_FILE=/etc/lme/pass.sh
        cd /home/lme-user/LME/scripts
        ./reset_elastic_password.exp kibana_system '${original_pw}'
    "

    http_code=$(docker_exec "$MASTER_CONTAINER" \
        "curl -sk -o /dev/null -w '%{http_code}' -u 'kibana_system:${original_pw}' https://localhost:9200/")
    if [ "$http_code" = "200" ]; then
        pass "Original kibana_system password restored via expect script"
    else
        fail "kibana_system password restore via expect failed (HTTP $http_code)"
    fi
}

# =========================================================================
# Test 7: password_management.sh — reset_wazuh_password (wazuh)
# =========================================================================
test_script_wazuh() {
    echo ""
    echo -e "${YELLOW}=== Test: password_management.sh / reset_wazuh_password (wazuh) ===${NC}"

    local original_wazuh_pw
    original_wazuh_pw=$(read_vault_secret "$MASTER_CONTAINER" "wazuh")
    local original_wazuh_api_pw
    original_wazuh_api_pw=$(read_vault_secret "$MASTER_CONTAINER" "wazuh_api")

    if [ -z "$original_wazuh_pw" ] || [ -z "$original_wazuh_api_pw" ]; then
        fail "Could not read current wazuh/wazuh_api passwords"
        return
    fi

    local test_pw="WazuhScript.Test_789"

    wait_for_wazuh || true

    # Source password_management.sh functions and call reset_wazuh_password
    echo "  Changing wazuh password via password_management.sh reset_wazuh_password..."
    docker_exec "$MASTER_CONTAINER" "
        export PATH=\$PATH:/nix/var/nix/profiles/default/bin
        export ANSIBLE_VAULT_PASSWORD_FILE=/etc/lme/pass.sh
        cd /home/lme-user/LME/scripts
        eval \"\$(sed '/^if \[ \\\$# -eq 0 \]/,/^fi\$/d; /^while getopts/,/^done\$/d' ./password_management.sh)\"
        reset_wazuh_password wazuh '${test_pw}'
    "
    local rc=$?
    if [ "$rc" -eq 0 ]; then
        pass "reset_wazuh_password exited 0"
    else
        fail "reset_wazuh_password exited $rc"
    fi

    # Verify both podman secrets were updated
    local new_wazuh_pw
    new_wazuh_pw=$(read_vault_secret "$MASTER_CONTAINER" "wazuh")
    if [ "$new_wazuh_pw" = "$test_pw" ]; then
        pass "Wazuh podman secret updated"
    else
        fail "Wazuh podman secret not updated (got length ${#new_wazuh_pw})"
    fi

    local new_wazuh_api_pw
    new_wazuh_api_pw=$(read_vault_secret "$MASTER_CONTAINER" "wazuh_api")
    if [ "$new_wazuh_api_pw" = "$test_pw" ]; then
        pass "Wazuh_api podman secret also updated (paired)"
    else
        fail "Wazuh_api podman secret not updated (got length ${#new_wazuh_api_pw})"
    fi

    wait_for_wazuh || true
    verify_wazuh_api

    # Restore
    echo "  Restoring wazuh password via password_management.sh..."
    docker_exec "$MASTER_CONTAINER" "
        export PATH=\$PATH:/nix/var/nix/profiles/default/bin
        export ANSIBLE_VAULT_PASSWORD_FILE=/etc/lme/pass.sh
        cd /home/lme-user/LME/scripts
        eval \"\$(sed '/^if \[ \\\$# -eq 0 \]/,/^fi\$/d; /^while getopts/,/^done\$/d' ./password_management.sh)\"
        reset_wazuh_password wazuh '${original_wazuh_pw}'
    "

    local restored_pw
    restored_pw=$(read_vault_secret "$MASTER_CONTAINER" "wazuh")
    if [ "$restored_pw" = "$original_wazuh_pw" ]; then
        pass "Original wazuh password restored via script"
    else
        fail "Wazuh password restore via script failed"
    fi

    wait_for_wazuh || true
}

# =========================================================================
# Run all tests
# =========================================================================
echo ""
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}  Part 1: Ansible change_passwords.yml  ${NC}"
echo -e "${YELLOW}========================================${NC}"
test_elastic
test_kibana_system
test_wazuh
test_wazuh_api

echo ""
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}  Part 2: password_management.sh        ${NC}"
echo -e "${YELLOW}========================================${NC}"
test_script_elastic
test_script_kibana_system
test_script_wazuh

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
