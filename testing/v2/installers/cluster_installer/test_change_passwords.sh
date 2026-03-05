#!/bin/bash

# test_change_passwords.sh
#
# Tests the change_passwords.yml Ansible playbook on a remote cluster deployed
# by setup_cluster.sh. Run from the host machine after setup_cluster.sh completes.
#
# Tests all supported users: elastic, kibana_system, wazuh, wazuh_api
# Also tests password_management.sh scripts (reset_elastic_password.exp,
# reset_wazuh_password).
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

ELASTIC_TEST_PASSWORD="ChangeMe_Test_Pwd_99.X"
WAZUH_TEST_PASSWORD="WazuhTest.Pass_789"
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
            echo "Tests all supported users: elastic, kibana_system, wazuh, wazuh_api"
            echo "Also tests password_management.sh expect scripts."
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

# =========================================================================
# Helper functions
# =========================================================================

# Run command on master via SSH
ssh_master() {
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "${LME_USER}@${MASTER_IP}" "$@"
}

# Run command on master via SSH with a TTY (needed by expect scripts)
ssh_master_tty() {
    ssh -t -o StrictHostKeyChecking=no -o ConnectTimeout=10 "${LME_USER}@${MASTER_IP}" "$@"
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

# Read a secret from master's vault by secret name
read_master_vault_secret() {
    local secret_name=$1
    ssh_master "sudo bash -s" <<REMOTE_SCRIPT
export PATH=\$PATH:/nix/var/nix/profiles/default/bin
export ANSIBLE_VAULT_PASSWORD_FILE=/etc/lme/pass.sh
SECRET_ID=\$(podman secret ls --noheading 2>/dev/null | awk '\$2 == "${secret_name}" { print \$1 }')
if [ -n "\$SECRET_ID" ] && [ -f "/etc/lme/vault/\$SECRET_ID" ]; then
    ansible-vault view /etc/lme/vault/\$SECRET_ID 2>/dev/null | tr -d "\n"
fi
REMOTE_SCRIPT
}

# Read a secret from a cluster node's vault (via SSH hop through master)
read_node_vault_secret() {
    local node_ip=$1
    local secret_name=$2
    ssh_master "ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 ${LME_USER}@${node_ip} 'sudo bash -s'" <<REMOTE_SCRIPT
export PATH=\$PATH:/nix/var/nix/profiles/default/bin
export ANSIBLE_VAULT_PASSWORD_FILE=/etc/lme/pass.sh
SECRET_ID=\$(podman secret ls --noheading 2>/dev/null | awk '\$2 == "${secret_name}" { print \$1 }')
if [ -n "\$SECRET_ID" ] && [ -f "/etc/lme/vault/\$SECRET_ID" ]; then
    ansible-vault view /etc/lme/vault/\$SECRET_ID 2>/dev/null | tr -d "\n"
fi
REMOTE_SCRIPT
}

# Run the change_passwords playbook on the master
run_change_password() {
    local user=$1
    local password=$2
    ssh_master "cd ~/LME && \
        ANSIBLE_LOCAL_TEMP=/tmp/ansible-tmp \
        ANSIBLE_REMOTE_TEMP=/tmp/ansible-tmp \
        ansible-playbook -i ansible/inventory/cluster.yml ansible/change_passwords.yml \
            -e lme_user=${user} \
            -e lme_password='${password}' \
            ${ANSIBLE_OPTS}"
}

# Verify ES cluster health using elastic credentials
verify_cluster_health() {
    local elastic_pw=$1
    local health_json
    health_json=$(ssh_master "curl -sk -u 'elastic:${elastic_pw}' https://localhost:9200/_cluster/health?pretty" 2>/dev/null || echo "{}")

    local health_status
    health_status=$(echo "$health_json" | grep '"status"' | sed 's/.*: "\(.*\)".*/\1/' || echo "unknown")
    local node_count
    node_count=$(echo "$health_json" | grep '"number_of_nodes"' | sed 's/[^0-9]//g' || echo "0")

    echo "  Status: $health_status"
    echo "  Nodes:  $node_count"

    if [ "$health_status" = "green" ] || [ "$health_status" = "yellow" ]; then
        pass "Cluster is healthy ($health_status)"
    else
        fail "Cluster health is $health_status"
    fi

    local expected_nodes=$((NODE_COUNT + 1))
    if [ "${node_count:-0}" -ge "$expected_nodes" ] 2>/dev/null; then
        pass "All $expected_nodes nodes present"
    else
        fail "Expected $expected_nodes nodes, got ${node_count:-unknown}"
    fi
}

# Wait for Wazuh daemons to be ready on the master
wait_for_wazuh() {
    echo "  Waiting for Wazuh daemons to be ready..."
    local retries=30
    local delay=10
    for i in $(seq 1 $retries); do
        local output
        output=$(ssh_master "sudo podman exec lme-wazuh-manager /var/ossec/bin/wazuh-control status 2>&1" 2>/dev/null || true)

        local all_ready=true
        for daemon in wazuh-modulesd wazuh-analysisd wazuh-execd wazuh-db wazuh-remoted wazuh-apid; do
            if echo "$output" | grep -q "$daemon not running"; then
                all_ready=false
                break
            fi
        done

        if $all_ready && echo "$output" | grep -q "is running"; then
            # Also verify the Wazuh API is actually accepting connections
            local api_code
            api_code=$(ssh_master "curl -sk -o /dev/null -w '%{http_code}' https://localhost:55000/" 2>/dev/null || echo "000")
            if [ "$api_code" = "401" ] || [ "$api_code" = "200" ]; then
                echo -e "  ${GREEN}Wazuh daemons ready${NC}"
                return 0
            fi
            # API not ready yet, continue waiting
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
    http_code=$(ssh_master "curl -sk -o /dev/null -w '%{http_code}' https://localhost:55000/" 2>/dev/null || echo "000")
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

# Get current elastic password for use in health checks throughout
CURRENT_ELASTIC_PW=$(read_master_vault_secret "elastic")
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
    original_pw=$(read_master_vault_secret "elastic")
    if [ -z "$original_pw" ]; then
        fail "Could not read current elastic password"
        return
    fi
    echo "  Current password length: ${#original_pw}"

    # Verify current password works
    local http_code
    http_code=$(ssh_master "curl -sk -o /dev/null -w '%{http_code}' -u 'elastic:${original_pw}' https://localhost:9200/_cluster/health" 2>/dev/null || echo "000")
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
    http_code=$(ssh_master "curl -sk -o /dev/null -w '%{http_code}' -u 'elastic:${ELASTIC_TEST_PASSWORD}' https://localhost:9200/_cluster/health" 2>/dev/null || echo "000")
    if [ "$http_code" = "200" ]; then
        pass "New password authenticates on master (HTTP 200)"
    else
        fail "New password returned HTTP $http_code on master"
    fi

    # Verify old password rejected
    http_code=$(ssh_master "curl -sk -o /dev/null -w '%{http_code}' -u 'elastic:${original_pw}' https://localhost:9200/_cluster/health" 2>/dev/null || echo "000")
    if [ "$http_code" = "401" ]; then
        pass "Old password correctly rejected (HTTP 401)"
    elif [ "$http_code" = "200" ]; then
        fail "Old password still works (HTTP 200) -- password was not changed"
    else
        pass "Old password rejected (HTTP $http_code)"
    fi

    # Verify secrets on cluster nodes
    echo "  Verifying secrets on cluster nodes..."
    for node_ip in $NODE_PRIVATE_IPS; do
        local node_pw
        node_pw=$(read_node_vault_secret "$node_ip" "elastic") 2>/dev/null || true
        if [ "$node_pw" = "$ELASTIC_TEST_PASSWORD" ]; then
            pass "Secret on $node_ip matches new password"
        else
            fail "Secret on $node_ip does not match (got length ${#node_pw})"
        fi
    done

    # Verify cluster health
    echo "  Checking cluster health..."
    verify_cluster_health "$ELASTIC_TEST_PASSWORD"

    # Restore original password
    echo "  Restoring original elastic password..."
    run_change_password "elastic" "$original_pw"

    http_code=$(ssh_master "curl -sk -o /dev/null -w '%{http_code}' -u 'elastic:${original_pw}' https://localhost:9200/_cluster/health" 2>/dev/null || echo "000")
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
    original_pw=$(read_master_vault_secret "kibana_system")
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
    new_pw=$(read_master_vault_secret "kibana_system")
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
    restored_pw=$(read_master_vault_secret "kibana_system")
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
    original_wazuh_pw=$(read_master_vault_secret "wazuh")
    local original_wazuh_api_pw
    original_wazuh_api_pw=$(read_master_vault_secret "wazuh_api")

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
    new_wazuh_pw=$(read_master_vault_secret "wazuh")
    if [ "$new_wazuh_pw" = "$WAZUH_TEST_PASSWORD" ]; then
        pass "Wazuh vault secret updated on master"
    else
        fail "Wazuh vault secret on master does not match new password"
    fi

    local new_wazuh_api_pw
    new_wazuh_api_pw=$(read_master_vault_secret "wazuh_api")
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
    restored_wazuh_pw=$(read_master_vault_secret "wazuh")
    local restored_wazuh_api_pw
    restored_wazuh_api_pw=$(read_master_vault_secret "wazuh_api")

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
    original_wazuh_pw=$(read_master_vault_secret "wazuh")
    local original_wazuh_api_pw
    original_wazuh_api_pw=$(read_master_vault_secret "wazuh_api")

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
    new_wazuh_api_pw=$(read_master_vault_secret "wazuh_api")
    if [ "$new_wazuh_api_pw" = "$WAZUH_TEST_PASSWORD" ]; then
        pass "Wazuh_api vault secret updated on master"
    else
        fail "Wazuh_api vault secret on master does not match new password"
    fi

    local new_wazuh_pw
    new_wazuh_pw=$(read_master_vault_secret "wazuh")
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
    restored_wazuh_pw=$(read_master_vault_secret "wazuh")
    local restored_wazuh_api_pw
    restored_wazuh_api_pw=$(read_master_vault_secret "wazuh_api")

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
    original_pw=$(read_master_vault_secret "elastic")
    if [ -z "$original_pw" ]; then
        fail "Could not read current elastic password"
        return
    fi

    local test_pw="ScriptTest.Pwd_42ab"

    # Change via expect script (needs TTY for podman exec -it inside)
    echo "  Changing elastic password via reset_elastic_password.exp..."
    ssh_master_tty "sudo bash -c '
        export PATH=\$PATH:/nix/var/nix/profiles/default/bin
        export ANSIBLE_VAULT_PASSWORD_FILE=/etc/lme/pass.sh
        cd /opt/lme/scripts
        ./reset_elastic_password.exp elastic \"${test_pw}\"
    '"
    local rc=$?
    if [ "$rc" -eq 0 ]; then
        pass "reset_elastic_password.exp exited 0"
    else
        fail "reset_elastic_password.exp exited $rc"
    fi

    # Verify new password works
    local http_code
    http_code=$(ssh_master "curl -sk -o /dev/null -w '%{http_code}' -u 'elastic:${test_pw}' https://localhost:9200/_cluster/health" 2>/dev/null || echo "000")
    if [ "$http_code" = "200" ]; then
        pass "New password authenticates via ES API (HTTP 200)"
    else
        fail "New password returned HTTP $http_code (expected 200)"
    fi

    # Verify old password rejected
    http_code=$(ssh_master "curl -sk -o /dev/null -w '%{http_code}' -u 'elastic:${original_pw}' https://localhost:9200/_cluster/health" 2>/dev/null || echo "000")
    if [ "$http_code" = "401" ]; then
        pass "Old password correctly rejected (HTTP 401)"
    else
        fail "Old password returned HTTP $http_code (expected 401)"
    fi

    # Restore via expect script
    echo "  Restoring elastic password via reset_elastic_password.exp..."
    ssh_master_tty "sudo bash -c '
        export PATH=\$PATH:/nix/var/nix/profiles/default/bin
        export ANSIBLE_VAULT_PASSWORD_FILE=/etc/lme/pass.sh
        cd /opt/lme/scripts
        ./reset_elastic_password.exp elastic \"${original_pw}\"
    '"

    http_code=$(ssh_master "curl -sk -o /dev/null -w '%{http_code}' -u 'elastic:${original_pw}' https://localhost:9200/_cluster/health" 2>/dev/null || echo "000")
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
    original_pw=$(read_master_vault_secret "kibana_system")
    if [ -z "$original_pw" ]; then
        fail "Could not read current kibana_system password"
        return
    fi

    local test_pw="KibanaScript.Test_42"

    echo "  Changing kibana_system password via reset_elastic_password.exp..."
    ssh_master_tty "sudo bash -c '
        export PATH=\$PATH:/nix/var/nix/profiles/default/bin
        export ANSIBLE_VAULT_PASSWORD_FILE=/etc/lme/pass.sh
        cd /opt/lme/scripts
        ./reset_elastic_password.exp kibana_system \"${test_pw}\"
    '"
    local rc=$?
    if [ "$rc" -eq 0 ]; then
        pass "reset_elastic_password.exp exited 0 for kibana_system"
    else
        fail "reset_elastic_password.exp exited $rc for kibana_system"
    fi

    # Verify new password works (kibana_system can auth to ES)
    local http_code
    http_code=$(ssh_master "curl -sk -o /dev/null -w '%{http_code}' -u 'kibana_system:${test_pw}' https://localhost:9200/" 2>/dev/null || echo "000")
    if [ "$http_code" = "200" ]; then
        pass "New kibana_system password authenticates (HTTP 200)"
    else
        fail "New kibana_system password returned HTTP $http_code (expected 200)"
    fi

    # Restore
    echo "  Restoring kibana_system password via reset_elastic_password.exp..."
    ssh_master_tty "sudo bash -c '
        export PATH=\$PATH:/nix/var/nix/profiles/default/bin
        export ANSIBLE_VAULT_PASSWORD_FILE=/etc/lme/pass.sh
        cd /opt/lme/scripts
        ./reset_elastic_password.exp kibana_system \"${original_pw}\"
    '"

    http_code=$(ssh_master "curl -sk -o /dev/null -w '%{http_code}' -u 'kibana_system:${original_pw}' https://localhost:9200/" 2>/dev/null || echo "000")
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
    original_wazuh_pw=$(read_master_vault_secret "wazuh")
    local original_wazuh_api_pw
    original_wazuh_api_pw=$(read_master_vault_secret "wazuh_api")

    if [ -z "$original_wazuh_pw" ] || [ -z "$original_wazuh_api_pw" ]; then
        fail "Could not read current wazuh/wazuh_api passwords"
        return
    fi

    local test_pw="WazuhScript.Test_789"

    wait_for_wazuh || true

    # Source password_management.sh functions and call reset_wazuh_password
    echo "  Changing wazuh password via password_management.sh reset_wazuh_password..."
    ssh_master "sudo bash -s" <<REMOTE_SCRIPT
export PATH=\$PATH:/nix/var/nix/profiles/default/bin
export ANSIBLE_VAULT_PASSWORD_FILE=/etc/lme/pass.sh
cd /opt/lme/scripts
eval "\$(sed '/^if \[ \\\$# -eq 0 \]/,/^fi\$/d; /^while getopts/,/^done\$/d' ./password_management.sh)"
reset_wazuh_password wazuh '${test_pw}'
REMOTE_SCRIPT
    local rc=$?
    if [ "$rc" -eq 0 ]; then
        pass "reset_wazuh_password exited 0"
    else
        fail "reset_wazuh_password exited $rc"
    fi

    # Verify both podman secrets were updated
    local new_wazuh_pw
    new_wazuh_pw=$(read_master_vault_secret "wazuh")
    if [ "$new_wazuh_pw" = "$test_pw" ]; then
        pass "Wazuh podman secret updated"
    else
        fail "Wazuh podman secret not updated (got length ${#new_wazuh_pw})"
    fi

    local new_wazuh_api_pw
    new_wazuh_api_pw=$(read_master_vault_secret "wazuh_api")
    if [ "$new_wazuh_api_pw" = "$test_pw" ]; then
        pass "Wazuh_api podman secret also updated (paired)"
    else
        fail "Wazuh_api podman secret not updated (got length ${#new_wazuh_api_pw})"
    fi

    wait_for_wazuh || true
    verify_wazuh_api

    # Restore
    echo "  Restoring wazuh password via password_management.sh..."
    ssh_master "sudo bash -s" <<REMOTE_SCRIPT
export PATH=\$PATH:/nix/var/nix/profiles/default/bin
export ANSIBLE_VAULT_PASSWORD_FILE=/etc/lme/pass.sh
cd /opt/lme/scripts
eval "\$(sed '/^if \[ \\\$# -eq 0 \]/,/^fi\$/d; /^while getopts/,/^done\$/d' ./password_management.sh)"
reset_wazuh_password wazuh '${original_wazuh_pw}'
REMOTE_SCRIPT

    local restored_pw
    restored_pw=$(read_master_vault_secret "wazuh")
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
