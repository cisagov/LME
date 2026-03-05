#!/bin/bash

# test_change_passwords.sh
#
# Tests the change_passwords.yml Ansible playbook on a remote cluster deployed
# by setup_cluster.sh. Run from the host machine after setup_cluster.sh completes.
#
# Uses the password and machine info files from setup_cluster.sh:
#   - ${RESOURCE_GROUP}.password.txt  (VM SSH password)
#   - ${RESOURCE_GROUP}.machines.json (cluster IPs and metadata)
#
# Prerequisites:
#   1. Run setup_cluster.sh to create the cluster
#   2. Run this test:  ./test_change_passwords.sh [-r RESOURCE_GROUP]
#
# Options:
#   -r, --resource-group NAME   Resource group name (default: from exporter.txt)
#   -d, --debug                 Enable verbose Ansible output
#   -h, --help                  Show help

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLERS_DIR="$(dirname "$SCRIPT_DIR")"

TEST_PASSWORD="ChangeMe_Test_Pwd_99!"
ANSIBLE_OPTS=""
TESTS_PASSED=0
TESTS_FAILED=0
RESOURCE_GROUP=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        -d|--debug)
            ANSIBLE_OPTS="-e lme_debug=true -v"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Tests change_passwords.yml on a remote cluster created by setup_cluster.sh."
            echo ""
            echo "OPTIONS:"
            echo "  -r, --resource-group NAME   Resource group (default: from exporter.txt)"
            echo "  -d, --debug                 Enable verbose Ansible output"
            echo "  -h, --help                  Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Load RESOURCE_GROUP and LME_USER from exporter.txt if not provided
if [ -z "$RESOURCE_GROUP" ]; then
    if [ -f "$INSTALLERS_DIR/exporter.txt" ]; then
        # shellcheck source=/dev/null
        source "$INSTALLERS_DIR/exporter.txt"
    fi
    if [ -z "${RESOURCE_GROUP:-}" ]; then
        echo -e "${RED}Error: RESOURCE_GROUP not set. Use -r/--resource-group or set in exporter.txt${NC}"
        exit 1
    fi
fi

LME_USER="${LME_USER:-lme-user}"

# Find password and machines files (check output/, parent dir, current dir)
PASSWORD_FILE=""
MACHINES_FILE=""
for base in "$SCRIPT_DIR/output" "$INSTALLERS_DIR" "$SCRIPT_DIR" .; do
    if [ -f "$base/${RESOURCE_GROUP}.password.txt" ]; then
        PASSWORD_FILE="$base/${RESOURCE_GROUP}.password.txt"
        break
    fi
done
for base in "$SCRIPT_DIR/output" "$INSTALLERS_DIR" "$SCRIPT_DIR" .; do
    if [ -f "$base/${RESOURCE_GROUP}.machines.json" ]; then
        MACHINES_FILE="$base/${RESOURCE_GROUP}.machines.json"
        break
    fi
done

if [ -z "$PASSWORD_FILE" ] || [ ! -f "$PASSWORD_FILE" ]; then
    echo -e "${RED}Error: ${RESOURCE_GROUP}.password.txt not found${NC}"
    echo "Looked in: output/, $INSTALLERS_DIR, $SCRIPT_DIR"
    exit 1
fi
if [ -z "$MACHINES_FILE" ] || [ ! -f "$MACHINES_FILE" ]; then
    echo -e "${RED}Error: ${RESOURCE_GROUP}.machines.json not found${NC}"
    echo "Looked in: output/, $INSTALLERS_DIR, $SCRIPT_DIR"
    exit 1
fi

VM_PASSWORD=$(cat "$PASSWORD_FILE")
MASTER_IP=$(jq -r '.linux_vms[0].ip_address' "$MACHINES_FILE")
MASTER_PRIVATE_IP=$(jq -r '.linux_vms[0].private_ip' "$MACHINES_FILE")
NODE_PRIVATE_IPS=$(jq -r '.linux_vms[1:][].private_ip' "$MACHINES_FILE")
NODE_COUNT=$(jq '.linux_vms[1:] | length' "$MACHINES_FILE")

# Helper: run command on master via SSH
ssh_master() {
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "${LME_USER}@${MASTER_IP}" "$@"
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
echo "  Resource group: $RESOURCE_GROUP"
echo "  Master: ${LME_USER}@${MASTER_IP}"

if ! command -v jq &>/dev/null; then
    echo -e "${RED}Error: jq is required. Install with: sudo apt-get install -y jq${NC}"
    exit 1
fi

echo -n "  Testing SSH to master... "
if ssh_master "echo ok" &>/dev/null; then
    echo -e "${GREEN}ok${NC}"
else
    echo -e "${RED}failed${NC}"
    echo "Ensure SSH key is copied to master (setup_cluster.sh does this) or use: ssh-copy-id ${LME_USER}@${MASTER_IP}"
    exit 1
fi

# =========================================================================
# Step 1: Get the current elastic password from master
# =========================================================================
echo ""
echo -e "${YELLOW}Step 1: Reading current elastic password from master${NC}"

ORIGINAL_PASSWORD=$(ssh_master 'sudo bash -s' << 'REMOTE_SCRIPT'
export PATH=$PATH:/nix/var/nix/profiles/default/bin
export ANSIBLE_VAULT_PASSWORD_FILE=/etc/lme/pass.sh
ELASTIC_ID=$(podman secret ls --noheading 2>/dev/null | awk '$2 == "elastic" { print $1 }')
if [ -n "$ELASTIC_ID" ] && [ -f "/etc/lme/vault/$ELASTIC_ID" ]; then
    ansible-vault view /etc/lme/vault/$ELASTIC_ID 2>/dev/null | tr -d "\n"
fi
REMOTE_SCRIPT
)

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

HTTP_CODE=$(ssh_master "curl -sk -o /dev/null -w '%{http_code}' -u 'elastic:${ORIGINAL_PASSWORD}' https://localhost:9200/_cluster/health" 2>/dev/null || echo "000")

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

ssh_master "cd ~/LME && \
    ANSIBLE_LOCAL_TEMP=/tmp/ansible-tmp \
    ANSIBLE_REMOTE_TEMP=/tmp/ansible-tmp \
    ansible-playbook -i ansible/inventory/cluster.yml ansible/change_passwords.yml \
        -e lme_user=elastic \
        -e lme_password='${TEST_PASSWORD}' \
        ${ANSIBLE_OPTS}"

echo -e "  ${GREEN}Playbook completed${NC}"

# =========================================================================
# Step 4: Verify new password works on master
# =========================================================================
echo ""
echo -e "${YELLOW}Step 4: Verifying new password works on master${NC}"

HTTP_CODE=$(ssh_master "curl -sk -o /dev/null -w '%{http_code}' -u 'elastic:${TEST_PASSWORD}' https://localhost:9200/_cluster/health" 2>/dev/null || echo "000")

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

HTTP_CODE=$(ssh_master "curl -sk -o /dev/null -w '%{http_code}' -u 'elastic:${ORIGINAL_PASSWORD}' https://localhost:9200/_cluster/health" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" = "401" ]; then
    pass "Old password correctly rejected (HTTP 401)"
elif [ "$HTTP_CODE" = "200" ]; then
    fail "Old password still works (HTTP 200) -- password was not changed"
else
    pass "Old password rejected (HTTP $HTTP_CODE)"
fi

# =========================================================================
# Step 6: Verify secrets were distributed to cluster nodes
# =========================================================================
echo ""
echo -e "${YELLOW}Step 6: Verifying secrets on cluster nodes${NC}"

for node_ip in $NODE_PRIVATE_IPS; do
    NODE_PASSWORD=$(ssh_master "ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 ${LME_USER}@${node_ip} 'sudo bash -s'" << 'REMOTE_SCRIPT'
export PATH=$PATH:/nix/var/nix/profiles/default/bin
export ANSIBLE_VAULT_PASSWORD_FILE=/etc/lme/pass.sh
ELASTIC_ID=$(podman secret ls --noheading 2>/dev/null | awk '$2 == "elastic" { print $1 }')
if [ -n "$ELASTIC_ID" ] && [ -f "/etc/lme/vault/$ELASTIC_ID" ]; then
    ansible-vault view /etc/lme/vault/$ELASTIC_ID 2>/dev/null | tr -d "\n"
fi
REMOTE_SCRIPT
) 2>/dev/null || true

    if [ "$NODE_PASSWORD" = "$TEST_PASSWORD" ]; then
        pass "Secret on $node_ip matches new password"
    else
        fail "Secret on $node_ip does not match (got length ${#NODE_PASSWORD})"
    fi
done

# =========================================================================
# Step 7: Verify cluster health
# =========================================================================
echo ""
echo -e "${YELLOW}Step 7: Checking cluster health${NC}"

HEALTH_JSON=$(ssh_master "curl -sk -u 'elastic:${TEST_PASSWORD}' https://localhost:9200/_cluster/health?pretty" 2>/dev/null || echo "{}")
HEALTH_STATUS=$(echo "$HEALTH_JSON" | grep '"status"' | sed 's/.*: "\(.*\)".*/\1/' || echo "unknown")
HEALTH_NODE_COUNT=$(echo "$HEALTH_JSON" | grep '"number_of_nodes"' | sed 's/[^0-9]//g' || echo "0")

echo "  Status: $HEALTH_STATUS"
echo "  Nodes:  $HEALTH_NODE_COUNT"

if [ "$HEALTH_STATUS" = "green" ] || [ "$HEALTH_STATUS" = "yellow" ]; then
    pass "Cluster is healthy ($HEALTH_STATUS)"
else
    fail "Cluster health is $HEALTH_STATUS"
fi

EXPECTED_NODES=$((NODE_COUNT + 1))
if [ "${HEALTH_NODE_COUNT:-0}" -ge "$EXPECTED_NODES" ] 2>/dev/null; then
    pass "All $EXPECTED_NODES nodes present"
else
    fail "Expected $EXPECTED_NODES nodes, got ${HEALTH_NODE_COUNT:-unknown}"
fi

# =========================================================================
# Step 8: Restore original password
# =========================================================================
echo ""
echo -e "${YELLOW}Step 8: Restoring original elastic password${NC}"

ssh_master "cd ~/LME && \
    ANSIBLE_LOCAL_TEMP=/tmp/ansible-tmp \
    ANSIBLE_REMOTE_TEMP=/tmp/ansible-tmp \
    ansible-playbook -i ansible/inventory/cluster.yml ansible/change_passwords.yml \
        -e lme_user=elastic \
        -e lme_password='${ORIGINAL_PASSWORD}' \
        ${ANSIBLE_OPTS}"

# Verify restore worked
HTTP_CODE=$(ssh_master "curl -sk -o /dev/null -w '%{http_code}' -u 'elastic:${ORIGINAL_PASSWORD}' https://localhost:9200/_cluster/health" 2>/dev/null || echo "000")

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
