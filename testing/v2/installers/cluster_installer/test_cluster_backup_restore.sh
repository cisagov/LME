#!/bin/bash

# test_cluster_backup_restore.sh
#
# End-to-end validation for the cluster-safe backup and recovery workflow on a
# remote cluster created by setup_cluster.sh.
#
# Prerequisites:
#   1. Run setup_cluster.sh
#   2. Run this test: ./test_cluster_backup_restore.sh [-r RESOURCE_GROUP]

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLERS_DIR="$(dirname "$SCRIPT_DIR")"

ANSIBLE_OPTS=""
TESTS_PASSED=0
TESTS_FAILED=0
RESOURCE_GROUP=""
SNAPSHOT_REPO="lme_nfs_backups"
SNAPSHOT_PATH="/usr/share/elasticsearch/snapshots"
SNAPSHOT_NAME="cluster-recovery-test-snapshot"
TEST_INDEX="lme-recovery-test-$(date +%s)"

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
    exit 1
fi
if [ -z "$MACHINES_FILE" ] || [ ! -f "$MACHINES_FILE" ]; then
    echo -e "${RED}Error: ${RESOURCE_GROUP}.machines.json not found${NC}"
    exit 1
fi

MASTER_IP=$(jq -r '.linux_vms[0].ip_address' "$MACHINES_FILE")

ssh_master() {
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "${LME_USER}@${MASTER_IP}" "$@"
}

pass() {
    echo -e "  ${GREEN}PASS${NC}: $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
    echo -e "  ${RED}FAIL${NC}: $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

parse_es_response() {
    local raw="$1"
    local expr="$2"
    if [ -z "$raw" ]; then
        echo -e "  ${RED}ERROR: Elasticsearch unreachable (empty response). Check Podman/systemd state on master.${NC}" >&2
        echo "ES_ERROR"
        return
    fi
    printf '%s' "$raw" | python3 -c "
import sys, json
raw = sys.stdin.read()
try:
    d = json.loads(raw)
    print($expr)
except (json.JSONDecodeError, KeyError, IndexError, TypeError) as e:
    print(f'ERROR: Failed to parse Elasticsearch response: {e}', file=sys.stderr)
    print(f'Raw response (first 300 chars): {raw[:300]}', file=sys.stderr)
    print('ES_ERROR')
"
}

cleanup() {
    ssh_master "sudo bash -s" <<SCRIPT >/dev/null 2>&1 || true
source /opt/lme/scripts/extract_secrets.sh -q 2>/dev/null || true
curl -sk -X DELETE -u "elastic:\$elastic" https://localhost:9200/${TEST_INDEX} >/dev/null 2>&1 || true
curl -sk -X DELETE -u "elastic:\$elastic" https://localhost:9200/_snapshot/${SNAPSHOT_REPO}/${SNAPSHOT_NAME} >/dev/null 2>&1 || true
SCRIPT
}

trap cleanup EXIT

echo -e "${YELLOW}=== Pre-flight Checks ===${NC}"
echo "  Resource group: $RESOURCE_GROUP"
echo "  Master: ${LME_USER}@${MASTER_IP}"

if ! command -v jq &>/dev/null; then
    echo -e "${RED}Error: jq is required.${NC}"
    exit 1
fi

echo -n "  Testing SSH to master... "
if ssh_master "echo ok" &>/dev/null; then
    echo -e "${GREEN}ok${NC}"
else
    echo -e "${RED}failed${NC}"
    exit 1
fi

if ssh_master "mountpoint -q /mnt/es-snapshots"; then
    pass "NFS snapshot mount present on master"
else
    fail "NFS snapshot mount missing on master"
    exit 1
fi

echo ""
echo -e "${YELLOW}Test 1: Create a recovery test index${NC}"
ssh_master "sudo bash -s" <<SCRIPT
source /opt/lme/scripts/extract_secrets.sh -q
curl -sk -u "elastic:\$elastic" -X PUT https://localhost:9200/${TEST_INDEX} \
  -H 'Content-Type: application/json' \
  -d '{"settings":{"number_of_shards":1,"number_of_replicas":1}}' >/dev/null
curl -sk -u "elastic:\$elastic" -X POST https://localhost:9200/${TEST_INDEX}/_doc/1?refresh=true \
  -H 'Content-Type: application/json' \
  -d '{"message":"cluster recovery test"}' >/dev/null
SCRIPT

INDEX_COUNT_RAW=$(ssh_master "sudo bash -s" <<SCRIPT
source /opt/lme/scripts/extract_secrets.sh -q
curl -sk -u "elastic:\$elastic" https://localhost:9200/${TEST_INDEX}/_count
SCRIPT
)
INDEX_COUNT=$(parse_es_response "$INDEX_COUNT_RAW" "d['count']")

if [ "$INDEX_COUNT" = "1" ]; then
    pass "Recovery test index created with one document"
else
    fail "Could not create recovery test index"
    exit 1
fi

echo ""
echo -e "${YELLOW}Test 2: Run cluster backup playbook${NC}"
ssh_master "cd ~/LME && \
    ANSIBLE_LOCAL_TEMP=/tmp/ansible-tmp \
    ANSIBLE_REMOTE_TEMP=/tmp/ansible-tmp \
    ansible-playbook -i ansible/inventory/cluster.yml ansible/cluster_backup_lme.yml \
      -e es_snapshot_fs_location=${SNAPSHOT_PATH} \
      -e es_snapshot_repo=${SNAPSHOT_REPO} \
      -e snapshot_name=${SNAPSHOT_NAME} \
      ${ANSIBLE_OPTS}"
pass "cluster_backup_lme.yml completed"

echo "  Waiting for Elasticsearch to become ready after backup (service was restarted)..."
for attempt in $(seq 1 30); do
    if ssh_master "sudo bash -s" <<'WAIT_SCRIPT' 2>/dev/null
source /opt/lme/scripts/extract_secrets.sh -q
curl -sk --max-time 5 -u "elastic:$elastic" https://localhost:9200/_cluster/health?wait_for_status=yellow\&timeout=5s >/dev/null 2>&1
WAIT_SCRIPT
    then
        echo "  Elasticsearch is ready (attempt ${attempt})"
        break
    fi
    if [ "$attempt" -eq 30 ]; then
        fail "Elasticsearch did not become ready within 5 minutes after backup"
        exit 1
    fi
    sleep 10
done

SNAPSHOT_STATE_RAW=$(ssh_master "sudo bash -s" <<SCRIPT
source /opt/lme/scripts/extract_secrets.sh -q
curl -sk -u "elastic:\$elastic" https://localhost:9200/_snapshot/${SNAPSHOT_REPO}/${SNAPSHOT_NAME}
SCRIPT
)
SNAPSHOT_STATE=$(parse_es_response "$SNAPSHOT_STATE_RAW" "d['snapshots'][0]['state']")

if [ "$SNAPSHOT_STATE" = "SUCCESS" ]; then
    pass "Cluster snapshot created successfully"
else
    fail "Cluster snapshot state is '$SNAPSHOT_STATE'"
fi

LATEST_BACKUP=$(ssh_master "sudo bash -c 'ls -1dt /var/lib/containers/storage/backups/* 2>/dev/null | head -n1'")
if ssh_master "sudo test -f ${LATEST_BACKUP}/cluster_recovery_manifest.yml"; then
    pass "Cluster recovery manifest created"
else
    fail "Cluster recovery manifest not found in ${LATEST_BACKUP}"
fi

# Prefer tarball exports; plain globs can pick a stale directory with a newer mtime than the new .tar.gz
EXPORTED_BACKUP=$(ssh_master "ls -1dt /mnt/es-snapshots/lme-master-backups/*.tar.gz 2>/dev/null | head -n1")
if [ -z "${EXPORTED_BACKUP:-}" ]; then
  EXPORTED_BACKUP=$(ssh_master "ls -1dt /mnt/es-snapshots/lme-master-backups/* 2>/dev/null | head -n1")
fi
# Shared export is a .tar.gz tarball (NFS-safe); legacy directory exports still supported
if [ -n "${EXPORTED_BACKUP:-}" ] && ssh_master "bash -s" <<EOS
set -euo pipefail
b="${EXPORTED_BACKUP}"
if [ -f "\$b" ] && [[ "\$b" == *.tar.gz ]]; then
  # Avoid tar|grep SIGPIPE/pipefail false failure when grep exits early after a match
  grep -q 'cluster_recovery_manifest.yml' < <(tar -tzf "\$b" 2>/dev/null)
elif [ -d "\$b" ] && [ -f "\$b/cluster_recovery_manifest.yml" ]; then
  exit 0
else
  exit 1
fi
EOS
then
    pass "Exported recovery bundle created on shared storage"
else
    fail "Exported recovery bundle not found on shared storage"
fi

echo ""
echo -e "${YELLOW}Test 3: Delete test index and restore it from snapshot${NC}"
POST_DELETE_CODE=$(ssh_master "sudo bash -s" <<SCRIPT
source /opt/lme/scripts/extract_secrets.sh -q
curl -sk -X DELETE -u "elastic:\$elastic" https://localhost:9200/${TEST_INDEX} >/dev/null
curl -sk -o /dev/null -w '%{http_code}' -u "elastic:\$elastic" https://localhost:9200/${TEST_INDEX}
SCRIPT
)

if [ "$POST_DELETE_CODE" = "404" ]; then
    pass "Test index deleted before restore"
else
    fail "Test index still exists before restore (HTTP $POST_DELETE_CODE)"
fi

ssh_master "cd ~/LME && \
    ANSIBLE_LOCAL_TEMP=/tmp/ansible-tmp \
    ANSIBLE_REMOTE_TEMP=/tmp/ansible-tmp \
    ansible-playbook -i ansible/inventory/cluster.yml ansible/restore_elasticsearch_snapshot.yml \
      -e es_snapshot_fs_location=${SNAPSHOT_PATH} \
      -e es_snapshot_repo=${SNAPSHOT_REPO} \
      -e snapshot_name=${SNAPSHOT_NAME} \
      -e restore_mode=live_cluster \
      -e restore_indices=${TEST_INDEX} \
      -e include_global_state=false \
      ${ANSIBLE_OPTS}"
pass "restore_elasticsearch_snapshot.yml completed"

RESTORED_COUNT_RAW=$(ssh_master "sudo bash -s" <<SCRIPT
source /opt/lme/scripts/extract_secrets.sh -q
curl -sk -u "elastic:\$elastic" https://localhost:9200/${TEST_INDEX}/_count
SCRIPT
)
RESTORED_COUNT=$(parse_es_response "$RESTORED_COUNT_RAW" "d['count']")

if [ "$RESTORED_COUNT" = "1" ]; then
    pass "Test index restored from snapshot"
else
    fail "Restored test index count is '$RESTORED_COUNT'"
fi

echo ""
echo -e "${YELLOW}Test 4: Restore master control-plane state from fresh backup bundle${NC}"
ssh_master "cd ~/LME && \
    ANSIBLE_LOCAL_TEMP=/tmp/ansible-tmp \
    ANSIBLE_REMOTE_TEMP=/tmp/ansible-tmp \
    ansible-playbook ansible/restore_lme_master.yml \
      -e restore_backup_dir=${EXPORTED_BACKUP} \
      ${ANSIBLE_OPTS}"
pass "restore_lme_master.yml completed"

echo "  Waiting for Elasticsearch to become ready after master restore..."
for attempt in $(seq 1 30); do
    if ssh_master "sudo bash -s" <<'WAIT_SCRIPT' 2>/dev/null
source /opt/lme/scripts/extract_secrets.sh -q
curl -sk --max-time 5 -u "elastic:$elastic" https://localhost:9200/_cluster/health?wait_for_status=yellow\&timeout=5s >/dev/null 2>&1
WAIT_SCRIPT
    then
        echo "  Elasticsearch is ready (attempt ${attempt})"
        break
    fi
    if [ "$attempt" -eq 30 ]; then
        fail "Elasticsearch did not become ready within 5 minutes after master restore"
        exit 1
    fi
    sleep 10
done

CLUSTER_HEALTH_RAW=$(ssh_master "sudo bash -s" <<SCRIPT
source /opt/lme/scripts/extract_secrets.sh -q
curl -sk -u "elastic:\$elastic" https://localhost:9200/_cluster/health
SCRIPT
)
CLUSTER_HEALTH=$(parse_es_response "$CLUSTER_HEALTH_RAW" "d['status']")

if [ "$CLUSTER_HEALTH" = "green" ] || [ "$CLUSTER_HEALTH" = "yellow" ]; then
    pass "Cluster health acceptable after master restore (${CLUSTER_HEALTH})"
else
    fail "Cluster health is ${CLUSTER_HEALTH} after master restore"
fi

MASTER_CONTAINER_COUNT=$(ssh_master "sudo podman ps --format '{{.Names}}' | grep -E 'lme' | wc -l")
if [ "$MASTER_CONTAINER_COUNT" -ge 4 ]; then
    pass "Master services came back after restore (${MASTER_CONTAINER_COUNT} containers)"
else
    fail "Expected at least 4 master containers, found ${MASTER_CONTAINER_COUNT}"
fi

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
