#!/bin/bash
# Full cluster test pipeline: setup -> wait for health -> test password change
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLERS_DIR="$(dirname "$SCRIPT_DIR")"
LOG="$SCRIPT_DIR/cluster_output.log"

source "$INSTALLERS_DIR/exporter.txt"

echo "=== [$(date)] Starting full cluster test pipeline ===" | tee -a "$LOG"

# Step 1: Build cluster and install LME
echo "=== [$(date)] Running setup_cluster.sh ===" | tee -a "$LOG"
cd "$SCRIPT_DIR"
./setup_cluster.sh 2>&1 | tee -a "$LOG"
echo "=== [$(date)] setup_cluster.sh complete ===" | tee -a "$LOG"

# Step 2: Wait for cluster to be green and all nodes present
echo "=== [$(date)] Waiting for cluster to be healthy and balanced ===" | tee -a "$LOG"

MACHINES_FILE="$SCRIPT_DIR/output/${RESOURCE_GROUP}.machines.json"
MASTER_IP=$(jq -r '.linux_vms[0].ip_address' "$MACHINES_FILE")
EXPECTED_NODES=$(jq '.linux_vms | length' "$MACHINES_FILE")

MAX_WAIT=60  # max 10 minutes (60 * 10s)
attempt=1
while [ $attempt -le $MAX_WAIT ]; do
    HEALTH_JSON=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "${LME_USER}@${MASTER_IP}" \
        "sudo bash -c 'source /opt/lme/scripts/extract_secrets.sh -q && curl -sk -u \"elastic:\$elastic\" https://localhost:9200/_cluster/health?pretty'" 2>/dev/null || echo "{}")
    STATUS=$(echo "$HEALTH_JSON" | grep '"status"' | sed 's/.*: "\(.*\)".*/\1/' || echo "unknown")
    NODES=$(echo "$HEALTH_JSON" | grep '"number_of_nodes"' | sed 's/[^0-9]//g' || echo "0")
    RELOCATING=$(echo "$HEALTH_JSON" | grep '"relocating_shards"' | sed 's/[^0-9]//g' || echo "-1")
    INITIALIZING=$(echo "$HEALTH_JSON" | grep '"initializing_shards"' | sed 's/[^0-9]//g' || echo "-1")
    echo "[$(date)] Health: status=$STATUS nodes=$NODES/$EXPECTED_NODES relocating=$RELOCATING initializing=$INITIALIZING" | tee -a "$LOG"
    if [ "$STATUS" = "green" ] && [ "${NODES:-0}" -ge "$EXPECTED_NODES" ] && [ "${RELOCATING:-1}" = "0" ] && [ "${INITIALIZING:-1}" = "0" ]; then
        echo "=== [$(date)] Cluster is green and balanced ===" | tee -a "$LOG"
        break
    fi
    if [ $attempt -eq $MAX_WAIT ]; then
        echo "=== [$(date)] WARNING: Cluster not fully balanced after max wait, proceeding anyway ===" | tee -a "$LOG"
    fi
    sleep 10
    ((attempt++))
done

# Step 3: Run password change test
echo "=== [$(date)] Running test_change_passwords.sh ===" | tee -a "$LOG"
cd "$SCRIPT_DIR"
./test_change_passwords.sh 2>&1 | tee -a "$LOG"
echo "=== [$(date)] test_change_passwords.sh complete ===" | tee -a "$LOG"
echo "=== [$(date)] Full pipeline DONE ===" | tee -a "$LOG"
