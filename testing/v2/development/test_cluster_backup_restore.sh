#!/bin/bash

# test_cluster_backup_restore.sh
#
# End-to-end validation for the cluster-safe backup and recovery workflow in the
# Docker development cluster.
#
# Prerequisites:
#   1. Start cluster:   docker compose -f docker-compose-cluster.yml up -d --build
#   2. Install cluster: bash install_cluster.sh
#   3. Run this test:   bash test_cluster_backup_restore.sh
#
# Note: Podman storage now persists per node via dedicated Docker volumes.
# Run `docker compose -f docker-compose-cluster.yml down -v` first if you need
# a fully clean dev cluster state before testing.

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

MASTER_CONTAINER="lme_cluster_node1"
NODE2_CONTAINER="lme_cluster_node2"
NODE3_CONTAINER="lme_cluster_node3"

ANSIBLE_OPTS=""
TESTS_PASSED=0
TESTS_FAILED=0
SNAPSHOT_REPO="lme_nfs_backups"
SNAPSHOT_PATH="/usr/share/elasticsearch/snapshots"
SNAPSHOT_NAME="cluster-recovery-test-snapshot"
TEST_INDEX="lme-recovery-test-$(date +%s)"

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

docker_exec() {
    local container=$1
    shift
    docker exec "$container" bash -c "$*"
}

docker_exec_as_lme_user() {
    local container=$1
    shift
    docker exec -u lme-user "$container" bash -c "$*"
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
    docker_exec "$MASTER_CONTAINER" "
        source /root/.profile 2>/dev/null || true
        source /opt/lme/scripts/extract_secrets.sh -q 2>/dev/null || true
        curl -sk -X DELETE -u \"elastic:\$elastic\" https://localhost:9200/${TEST_INDEX} >/dev/null 2>&1 || true
        curl -sk -X DELETE -u \"elastic:\$elastic\" https://localhost:9200/_snapshot/${SNAPSHOT_REPO}/${SNAPSHOT_NAME} >/dev/null 2>&1 || true
    " >/dev/null 2>&1 || true
}

trap cleanup EXIT

echo -e "${YELLOW}=== Pre-flight Checks ===${NC}"
for container in "$MASTER_CONTAINER" "$NODE2_CONTAINER" "$NODE3_CONTAINER"; do
    if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        echo -e "${RED}Container $container is not running.${NC}"
        exit 1
    fi
done
echo -e "  ${GREEN}All required containers running${NC}"

if docker_exec "$MASTER_CONTAINER" "mountpoint -q /mnt/es-snapshots"; then
    pass "NFS snapshot mount present on master"
else
    fail "NFS snapshot mount missing on master"
    exit 1
fi

echo ""
echo -e "${YELLOW}Test 1: Create a recovery test index${NC}"
INDEX_CREATE_RESULT=$(docker_exec "$MASTER_CONTAINER" "
    source /root/.profile 2>/dev/null || true
    source /opt/lme/scripts/extract_secrets.sh -q 2>/dev/null
    curl -sk -u \"elastic:\$elastic\" -X PUT https://localhost:9200/${TEST_INDEX} \
      -H 'Content-Type: application/json' \
      -d '{\"settings\":{\"number_of_shards\":1,\"number_of_replicas\":1}}'
")

DOC_CREATE_RESULT=$(docker_exec "$MASTER_CONTAINER" "
    source /root/.profile 2>/dev/null || true
    source /opt/lme/scripts/extract_secrets.sh -q 2>/dev/null
    curl -sk -u \"elastic:\$elastic\" -X POST https://localhost:9200/${TEST_INDEX}/_doc/1?refresh=true \
      -H 'Content-Type: application/json' \
      -d '{\"message\":\"cluster recovery test\"}'
")

INDEX_COUNT_RAW=$(docker_exec "$MASTER_CONTAINER" "
    source /root/.profile 2>/dev/null || true
    source /opt/lme/scripts/extract_secrets.sh -q 2>/dev/null
    curl -sk -u \"elastic:\$elastic\" https://localhost:9200/${TEST_INDEX}/_count
")
INDEX_COUNT=$(parse_es_response "$INDEX_COUNT_RAW" "d['count']")

if [[ "$INDEX_CREATE_RESULT" == *"acknowledged"* && "$DOC_CREATE_RESULT" == *"created"* && "$INDEX_COUNT" = "1" ]]; then
    pass "Recovery test index created with one document"
else
    fail "Could not create recovery test index"
    exit 1
fi

echo ""
echo -e "${YELLOW}Test 2: Run cluster backup playbook${NC}"
docker_exec_as_lme_user "$MASTER_CONTAINER" "
    cd ~/LME && \
    ANSIBLE_LOCAL_TEMP=/tmp/ansible-tmp \
    ANSIBLE_REMOTE_TEMP=/tmp/ansible-tmp \
    ansible-playbook -i ansible/inventory/cluster.yml ansible/cluster_backup_lme.yml \
      -e es_snapshot_fs_location=${SNAPSHOT_PATH} \
      -e es_snapshot_repo=${SNAPSHOT_REPO} \
      -e snapshot_name=${SNAPSHOT_NAME} \
      ${ANSIBLE_OPTS}
"
pass "cluster_backup_lme.yml completed"

SNAPSHOT_STATE_RAW=$(docker_exec "$MASTER_CONTAINER" "
    source /root/.profile 2>/dev/null || true
    source /opt/lme/scripts/extract_secrets.sh -q 2>/dev/null
    curl -sk -u \"elastic:\$elastic\" https://localhost:9200/_snapshot/${SNAPSHOT_REPO}/${SNAPSHOT_NAME}
")
SNAPSHOT_STATE=$(parse_es_response "$SNAPSHOT_STATE_RAW" "d['snapshots'][0]['state']")

if [ "$SNAPSHOT_STATE" = "SUCCESS" ]; then
    pass "Cluster snapshot created successfully"
else
    fail "Cluster snapshot state is '$SNAPSHOT_STATE'"
fi

LATEST_BACKUP=$(docker_exec "$MASTER_CONTAINER" "sudo bash -c 'ls -1dt /var/lib/containers/storage/backups/* 2>/dev/null | head -n1'")
if docker_exec "$MASTER_CONTAINER" "sudo test -f ${LATEST_BACKUP}/cluster_recovery_manifest.yml"; then
    pass "Cluster recovery manifest created"
else
    fail "Cluster recovery manifest not found in ${LATEST_BACKUP}"
fi

EXPORTED_BACKUP=$(docker_exec "$MASTER_CONTAINER" "ls -1dt /mnt/es-snapshots/lme-master-backups/*.tar.gz 2>/dev/null | head -n1")
if [ -z "${EXPORTED_BACKUP:-}" ]; then
  EXPORTED_BACKUP=$(docker_exec "$MASTER_CONTAINER" "ls -1dt /mnt/es-snapshots/lme-master-backups/* 2>/dev/null | head -n1")
fi
# Shared export is a .tar.gz tarball (NFS-safe); legacy directory exports still supported
# (docker_exec does not forward stdin; use docker exec -c for multi-line remote script)
if [ -n "${EXPORTED_BACKUP:-}" ] && docker exec "$MASTER_CONTAINER" bash -c "
set -euo pipefail
b=\"${EXPORTED_BACKUP}\"
if [ -f \"\$b\" ] && [[ \"\$b\" == *.tar.gz ]]; then
  grep -q cluster_recovery_manifest.yml < <(tar -tzf \"\$b\" 2>/dev/null)
elif [ -d \"\$b\" ] && [ -f \"\$b/cluster_recovery_manifest.yml\" ]; then
  exit 0
else
  exit 1
fi
"; then
    pass "Exported recovery bundle created on shared storage"
else
    fail "Exported recovery bundle not found on shared storage"
fi

echo ""
echo -e "${YELLOW}Test 3: Delete test index and restore it from snapshot${NC}"
docker_exec "$MASTER_CONTAINER" "
    source /root/.profile 2>/dev/null || true
    source /opt/lme/scripts/extract_secrets.sh -q 2>/dev/null
    curl -sk -X DELETE -u \"elastic:\$elastic\" https://localhost:9200/${TEST_INDEX}
" >/dev/null

POST_DELETE_CODE=$(docker_exec "$MASTER_CONTAINER" "
    source /root/.profile 2>/dev/null || true
    source /opt/lme/scripts/extract_secrets.sh -q 2>/dev/null
    curl -sk -o /dev/null -w '%{http_code}' -u \"elastic:\$elastic\" https://localhost:9200/${TEST_INDEX}
")

if [ "$POST_DELETE_CODE" = "404" ]; then
    pass "Test index deleted before restore"
else
    fail "Test index still exists before restore (HTTP $POST_DELETE_CODE)"
fi

docker_exec_as_lme_user "$MASTER_CONTAINER" "
    cd ~/LME && \
    ANSIBLE_LOCAL_TEMP=/tmp/ansible-tmp \
    ANSIBLE_REMOTE_TEMP=/tmp/ansible-tmp \
    ansible-playbook -i ansible/inventory/cluster.yml ansible/restore_elasticsearch_snapshot.yml \
      -e es_snapshot_fs_location=${SNAPSHOT_PATH} \
      -e es_snapshot_repo=${SNAPSHOT_REPO} \
      -e snapshot_name=${SNAPSHOT_NAME} \
      -e restore_mode=live_cluster \
      -e restore_indices=${TEST_INDEX} \
      -e include_global_state=false \
      ${ANSIBLE_OPTS}
"
pass "restore_elasticsearch_snapshot.yml completed"

RESTORED_COUNT_RAW=$(docker_exec "$MASTER_CONTAINER" "
    source /root/.profile 2>/dev/null || true
    source /opt/lme/scripts/extract_secrets.sh -q 2>/dev/null
    curl -sk -u \"elastic:\$elastic\" https://localhost:9200/${TEST_INDEX}/_count
")
RESTORED_COUNT=$(parse_es_response "$RESTORED_COUNT_RAW" "d['count']")

if [ "$RESTORED_COUNT" = "1" ]; then
    pass "Test index restored from snapshot"
else
    fail "Restored test index count is '$RESTORED_COUNT'"
fi

echo ""
echo -e "${YELLOW}Test 4: Restore master control-plane state from fresh backup bundle${NC}"
docker_exec_as_lme_user "$MASTER_CONTAINER" "
    cd ~/LME && \
    ANSIBLE_LOCAL_TEMP=/tmp/ansible-tmp \
    ANSIBLE_REMOTE_TEMP=/tmp/ansible-tmp \
    ansible-playbook ansible/restore_lme_master.yml \
      -e restore_backup_dir=${EXPORTED_BACKUP} \
      ${ANSIBLE_OPTS}
"
pass "restore_lme_master.yml completed"

CLUSTER_HEALTH_RAW=$(docker_exec "$MASTER_CONTAINER" "
    source /root/.profile 2>/dev/null || true
    source /opt/lme/scripts/extract_secrets.sh -q 2>/dev/null
    curl -sk -u \"elastic:\$elastic\" https://localhost:9200/_cluster/health
")
CLUSTER_HEALTH=$(parse_es_response "$CLUSTER_HEALTH_RAW" "d['status']")

if [ "$CLUSTER_HEALTH" = "green" ] || [ "$CLUSTER_HEALTH" = "yellow" ]; then
    pass "Cluster health acceptable after master restore (${CLUSTER_HEALTH})"
else
    fail "Cluster health is ${CLUSTER_HEALTH} after master restore"
fi

MASTER_CONTAINER_COUNT=$(docker_exec "$MASTER_CONTAINER" "podman ps --format '{{.Names}}' | grep -E 'lme' | wc -l")
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
