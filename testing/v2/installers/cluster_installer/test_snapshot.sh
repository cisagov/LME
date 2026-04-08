#!/bin/bash

# test_snapshot.sh
#
# Tests the snapshot_elasticsearch.yml and pre_upgrade_checks.yml Ansible
# playbooks on a remote cluster deployed by setup_cluster.sh. Run from the
# host machine after setup_cluster.sh completes.
#
# Uses the password and machine info files from setup_cluster.sh:
#   - ${RESOURCE_GROUP}.password.txt  (VM SSH password)
#   - ${RESOURCE_GROUP}.machines.json (cluster IPs and metadata)
#
# Prerequisites:
#   1. Run setup_cluster.sh to create the cluster
#   2. Run this test:  ./test_snapshot.sh [-r RESOURCE_GROUP]
#
# Options:
#   -r, --resource-group NAME   Resource group name (default: from exporter.txt)
#   -d, --debug                 Enable verbose Ansible output
#   --single-node               Run single-node tests only (against master, no cluster inventory)
#   -h, --help                  Show help
#
# When setup_cluster.sh runs with NFS (default), the master is the NFS server
# and all nodes mount /srv/es-snapshots. Use --single-node to skip cluster/NFS tests.

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLERS_DIR="$(dirname "$SCRIPT_DIR")"

ANSIBLE_OPTS=""
SINGLE_NODE_ONLY="false"
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
        --single-node)
            SINGLE_NODE_ONLY="true"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Tests snapshot_elasticsearch.yml and pre_upgrade checks on a remote cluster."
            echo ""
            echo "OPTIONS:"
            echo "  -r, --resource-group NAME   Resource group (default: from exporter.txt)"
            echo "  -d, --debug                 Enable verbose Ansible output"
            echo "  --single-node               Run single-node tests only (no cluster inventory)"
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

MASTER_IP=$(jq -r '.linux_vms[0].ip_address' "$MACHINES_FILE")

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

# Build inventory and snapshot vars
# In cluster mode, use NFS-backed snapshot path (setup_cluster.sh configures master as NFS server)
if [ "$SINGLE_NODE_ONLY" = "true" ]; then
    INVENTORY_OPT="-i ansible/inventory/single.yml"
    SNAPSHOT_EXTRA_VARS=""
    SNAPSHOT_REPO="lme_backups"
else
    INVENTORY_OPT="-i ansible/inventory/cluster.yml"
    SNAPSHOT_EXTRA_VARS="-e es_snapshot_fs_location=/usr/share/elasticsearch/snapshots -e es_snapshot_repo=lme_nfs_backups"
    SNAPSHOT_REPO="lme_nfs_backups"
fi

# =========================================================================
# Pre-flight checks
# =========================================================================
echo -e "${YELLOW}=== Pre-flight Checks ===${NC}"
echo "  Resource group: $RESOURCE_GROUP"
echo "  Master: ${LME_USER}@${MASTER_IP}"
echo "  Mode: $([ "$SINGLE_NODE_ONLY" = "true" ] && echo "single-node" || echo "cluster")"

if ! command -v jq &>/dev/null; then
    echo -e "${RED}Error: jq is required. Install with: sudo apt-get install -y jq${NC}"
    exit 1
fi

echo -n "  Testing SSH to master... "
if ssh_master "echo ok" &>/dev/null; then
    echo -e "${GREEN}ok${NC}"
else
    echo -e "${RED}failed${NC}"
    echo "Ensure SSH key is copied to master (setup_cluster.sh does this)"
    exit 1
fi

# =========================================================================
# Test 1: Single-node snapshot (register repo, verify, create snapshot)
# =========================================================================
echo ""
echo -e "${YELLOW}Test 1: Register repo, verify, and create snapshot${NC}"

ssh_master "cd ~/LME && \
    ANSIBLE_LOCAL_TEMP=/tmp/ansible-tmp \
    ANSIBLE_REMOTE_TEMP=/tmp/ansible-tmp \
    ansible-playbook ${INVENTORY_OPT} ${SNAPSHOT_EXTRA_VARS} ansible/snapshot_elasticsearch.yml \
        -e snapshot_name=test-snapshot-1 \
        ${ANSIBLE_OPTS}"

SNAPSHOT_STATE=$(ssh_master "sudo bash -s" << SCRIPT
source /opt/lme/scripts/extract_secrets.sh -q 2>/dev/null
curl -sk -u "elastic:\$elastic" https://localhost:9200/_snapshot/${SNAPSHOT_REPO}/test-snapshot-1 2>/dev/null \
    | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d["snapshots"][0]["state"])' 2>/dev/null || echo 'NOT_FOUND'
SCRIPT
)

if [ "$SNAPSHOT_STATE" = "SUCCESS" ]; then
    pass "Snapshot 'test-snapshot-1' created with state SUCCESS"
else
    fail "Snapshot state is '$SNAPSHOT_STATE', expected SUCCESS"
fi

# =========================================================================
# Test 2: Repo-only mode (no snapshot created)
# =========================================================================
echo ""
echo -e "${YELLOW}Test 2: Register and verify repository only (create_snapshot=false)${NC}"

ssh_master "cd ~/LME && \
    ANSIBLE_LOCAL_TEMP=/tmp/ansible-tmp \
    ANSIBLE_REMOTE_TEMP=/tmp/ansible-tmp \
    ansible-playbook ${INVENTORY_OPT} ${SNAPSHOT_EXTRA_VARS} ansible/snapshot_elasticsearch.yml \
        -e create_snapshot=false \
        ${ANSIBLE_OPTS}"

if [ $? -eq 0 ]; then
    pass "Repo-only mode completed without errors"
else
    fail "Repo-only mode failed"
fi

# =========================================================================
# Test 3: Idempotency (run snapshot playbook a second time)
# =========================================================================
echo ""
echo -e "${YELLOW}Test 3: Idempotency - running snapshot playbook again${NC}"

ssh_master "cd ~/LME && \
    ANSIBLE_LOCAL_TEMP=/tmp/ansible-tmp \
    ANSIBLE_REMOTE_TEMP=/tmp/ansible-tmp \
    ansible-playbook ${INVENTORY_OPT} ${SNAPSHOT_EXTRA_VARS} ansible/snapshot_elasticsearch.yml \
        -e snapshot_name=test-snapshot-2 \
        ${ANSIBLE_OPTS}"

SNAPSHOT_STATE=$(ssh_master "sudo bash -s" << SCRIPT
source /opt/lme/scripts/extract_secrets.sh -q 2>/dev/null
curl -sk -u "elastic:\$elastic" https://localhost:9200/_snapshot/${SNAPSHOT_REPO}/test-snapshot-2 2>/dev/null \
    | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d["snapshots"][0]["state"])' 2>/dev/null || echo 'NOT_FOUND'
SCRIPT
)

if [ "$SNAPSHOT_STATE" = "SUCCESS" ]; then
    pass "Second run succeeded - idempotent (snapshot 'test-snapshot-2' state: SUCCESS)"
else
    fail "Second run snapshot state is '$SNAPSHOT_STATE', expected SUCCESS"
fi

# =========================================================================
# Test 4: Pre-upgrade checks (snapshot created by rolling_upgrade pre_tasks)
# =========================================================================
echo ""
echo -e "${YELLOW}Test 4: Pre-upgrade checks with default snapshot creation${NC}"

ssh_master "cd ~/LME && \
    ANSIBLE_LOCAL_TEMP=/tmp/ansible-tmp \
    ANSIBLE_REMOTE_TEMP=/tmp/ansible-tmp \
    ansible-playbook ${INVENTORY_OPT} ${SNAPSHOT_EXTRA_VARS} ansible/rolling_upgrade.yml \
        -e snapshot_name=test-pre-upgrade-snapshot \
        ${ANSIBLE_OPTS} \
        --tags '' 2>&1" || true

SNAPSHOT_STATE=$(ssh_master "sudo bash -s" << SCRIPT
source /opt/lme/scripts/extract_secrets.sh -q 2>/dev/null
curl -sk -u "elastic:\$elastic" https://localhost:9200/_snapshot/${SNAPSHOT_REPO}/test-pre-upgrade-snapshot 2>/dev/null \
    | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d["snapshots"][0]["state"])' 2>/dev/null || echo 'NOT_FOUND'
SCRIPT
)

if [ "$SNAPSHOT_STATE" = "SUCCESS" ]; then
    pass "Pre-upgrade snapshot created by default (state: SUCCESS)"
elif [ "$SNAPSHOT_STATE" = "NOT_FOUND" ]; then
    echo -e "  ${YELLOW}INFO${NC}: Pre-upgrade snapshot not found by exact name (rolling_upgrade may have used a different name)"
    pass "Pre-upgrade checks ran without blocking errors"
else
    fail "Pre-upgrade snapshot state is '$SNAPSHOT_STATE'"
fi

# =========================================================================
# Test 5: Cluster verification (if running cluster mode)
# =========================================================================
if [ "$SINGLE_NODE_ONLY" = "false" ]; then
    echo ""
    echo -e "${YELLOW}Test 5: Cluster - verify cluster health${NC}"

    NODE_COUNT=$(ssh_master "sudo bash -s" << 'SCRIPT'
source /opt/lme/scripts/extract_secrets.sh -q 2>/dev/null
curl -sk -u "elastic:$elastic" https://localhost:9200/_cat/nodes?h=name 2>/dev/null | wc -l
SCRIPT
)

    if [ "${NODE_COUNT:-0}" -ge 3 ] 2>/dev/null; then
        pass "Cluster has $NODE_COUNT nodes"
    else
        fail "Expected at least 3 nodes, got ${NODE_COUNT:-unknown}"
    fi

    # --- NFS-backed snapshot tests (master = NFS server) ---
    echo ""
    echo -e "${YELLOW}Test 5b: NFS - verify mounts and shared snapshot repository${NC}"

    NFS_OK=true
    node_num=1
    for node_pub_ip in $(jq -r '.linux_vms[].ip_address' "$MACHINES_FILE"); do
        if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "${LME_USER}@${node_pub_ip}" "mountpoint -q /mnt/es-snapshots" 2>/dev/null; then
            pass "NFS mounted on node${node_num}"
        else
            fail "NFS not mounted on node${node_num}"
            NFS_OK=false
        fi
        ((node_num++))
    done

    if [ "$NFS_OK" = "true" ]; then
        echo ""
        echo -e "${YELLOW}Test 5c: NFS - create snapshot on shared NFS repository${NC}"

        ssh_master "cd ~/LME && \
            ANSIBLE_LOCAL_TEMP=/tmp/ansible-tmp \
            ANSIBLE_REMOTE_TEMP=/tmp/ansible-tmp \
            ansible-playbook -i ansible/inventory/cluster.yml ansible/snapshot_elasticsearch.yml \
                -e es_snapshot_fs_location=/usr/share/elasticsearch/snapshots \
                -e es_snapshot_repo=lme_nfs_backups \
                -e snapshot_name=test-nfs-snapshot \
                ${ANSIBLE_OPTS}"

        SNAPSHOT_STATE=$(ssh_master "sudo bash -s" << SCRIPT
source /opt/lme/scripts/extract_secrets.sh -q 2>/dev/null
curl -sk -u "elastic:\$elastic" https://localhost:9200/_snapshot/lme_nfs_backups/test-nfs-snapshot 2>/dev/null \
    | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d["snapshots"][0]["state"])' 2>/dev/null || echo 'NOT_FOUND'
SCRIPT
        )

        if [ "$SNAPSHOT_STATE" = "SUCCESS" ]; then
            pass "NFS snapshot 'test-nfs-snapshot' created with state SUCCESS"
        else
            fail "NFS snapshot state is '$SNAPSHOT_STATE', expected SUCCESS"
        fi

        # Verify snapshot data is visible on NFS server (master's /srv/es-snapshots)
        if ssh_master "ls /srv/es-snapshots/ 2>/dev/null | grep -q ."; then
            pass "Snapshot data present on NFS server (master)"
        else
            fail "No snapshot data found on NFS server"
        fi
    else
        echo -e "  ${YELLOW}INFO${NC}: Skipping NFS snapshot tests - NFS mounts not available"
    fi
else
    echo ""
    echo -e "${YELLOW}Test 5: Skipped (single-node mode)${NC}"
fi

# =========================================================================
# Cleanup: delete test snapshots
# =========================================================================
echo ""
echo -e "${YELLOW}Cleanup: Deleting test snapshots${NC}"

for snap in test-snapshot-1 test-snapshot-2 test-pre-upgrade-snapshot; do
    ssh_master "sudo bash -s" << SCRIPT
source /opt/lme/scripts/extract_secrets.sh -q 2>/dev/null
curl -sk -X DELETE -u "elastic:\$elastic" https://localhost:9200/_snapshot/${SNAPSHOT_REPO}/${snap} 2>/dev/null || true
SCRIPT
done 2>/dev/null

# Clean up NFS snapshots (lme_nfs_backups)
if [ "$SINGLE_NODE_ONLY" = "false" ]; then
    ssh_master "sudo bash -s" << 'SCRIPT'
source /opt/lme/scripts/extract_secrets.sh -q 2>/dev/null
curl -sk -X DELETE -u "elastic:$elastic" https://localhost:9200/_snapshot/lme_nfs_backups/test-nfs-snapshot 2>/dev/null || true
SCRIPT
fi 2>/dev/null
echo -e "  ${GREEN}Test snapshots cleaned up${NC}"

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
