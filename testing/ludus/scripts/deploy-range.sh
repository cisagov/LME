#!/usr/bin/env bash
# deploy-range.sh — Deploy a range via Ludus CLI, sync code, install monitors
#
# @decision DEC-DEPLOY-RANGE-002
# @title Use ludus CLI for deploy, rsync for local repos, SSH for upgrades
# @status accepted
# @rationale The Ludus CLI handles config set, deploy, status polling, and
#   abort natively. For local repo paths, rsync pushes code after deploy.
#   For upgrades, SSH runs install.sh after switching branches. Monitors
#   are always installed to prevent QCOW2 disk bloat.
#
# Usage:
#   bash scripts/deploy-range.sh <range-dir>
#   bash scripts/deploy-range.sh ranges/fresh-23
#
# Requires: ludus CLI, sshpass, rsync (if LME_REPO_URL is a local path)
# Ludus config: ~/.ludus/config OR LUDUS_API_KEY env var

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RANGE_DIR="${1:?Usage: deploy-range.sh <range-dir>}"

if [ ! -f "$RANGE_DIR/range-config.yml" ]; then
    echo "ERROR: $RANGE_DIR/range-config.yml not found"
    echo "       Run: bash scripts/generate-range.sh $RANGE_DIR"
    exit 1
fi
if [ ! -f "$RANGE_DIR/params.yml" ]; then
    echo "ERROR: $RANGE_DIR/params.yml not found"
    exit 1
fi

# Validate and read params
PARAMS_FILE="$RANGE_DIR/params.yml"
source "$SCRIPT_DIR/lib-params.sh"
validate_params

# Check ludus CLI
if ! command -v ludus >/dev/null 2>&1; then
    echo "ERROR: ludus CLI not found. Install from https://gitlab.com/badsectorlabs/ludus/-/releases"
    exit 1
fi

RANGE_NAME=$(read_param RANGE_NAME)
SSH_USER=$(read_param SSH_USER)
SSH_PASS=$(read_param SSH_PASS)
LME_BRANCH=$(read_param LME_BRANCH)
LME_REPO_URL=$(read_param LME_REPO_URL "https://github.com/cisagov/LME.git")
UPGRADE_FROM_BRANCH=$(read_param UPGRADE_FROM_BRANCH "")

SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
SSH_CMD="sshpass -p $SSH_PASS ssh $SSH_OPTS"

# Find repo root from script location (for rsync fallback)
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ]; do
    [ -d "$REPO_ROOT/.git" ] || [ -f "$REPO_ROOT/.git" ] && break
    REPO_ROOT="$(dirname "$REPO_ROOT")"
done

# Determine rsync source: explicit local path or detected repo root
rsync_source() {
    if [ -d "$LME_REPO_URL" ]; then
        echo "$LME_REPO_URL"
    elif echo "$LME_REPO_URL" | grep -qE '^/' && [ -n "$REPO_ROOT" ] && [ "$REPO_ROOT" != "/" ]; then
        echo "$REPO_ROOT"
    else
        echo ""
    fi
}

sync_to_server() {
    local target_ip="$1"
    local src
    src=$(rsync_source)
    if [ -n "$src" ]; then
        if ! command -v rsync >/dev/null 2>&1; then
            echo "ERROR: rsync required for local repo deploy. Install: apt install rsync" >&2
            exit 1
        fi
        echo "  Rsyncing $src → $target_ip:/opt/lme-install/ ..."
        sshpass -p "$SSH_PASS" rsync -az --delete \
            -e "ssh $SSH_OPTS" \
            --exclude 'node_modules' --exclude 'tmp/' --exclude '.worktrees' \
            "$src/" "$SSH_USER@$target_ip:/tmp/lme-sync/"
        $SSH_CMD "$SSH_USER@$target_ip" "sudo rsync -a --delete /tmp/lme-sync/ /opt/lme-install/ && rm -rf /tmp/lme-sync"
        echo "  Done."
    fi
}

echo "=== Deploying range: $RANGE_NAME ==="

# Step 0: Push Ansible roles to Ludus server (ensures latest code)
echo "Pushing Ansible roles to Ludus..."
ROLES_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")/ansible/roles"
for role in ludus_lme_server ludus_lme_agents; do
    if [ -d "$ROLES_DIR/$role" ]; then
        ludus_cmd ansible role add -d "$ROLES_DIR/$role" --force 2>&1 | grep -v "^$"
    fi
done
echo ""

# Step 1: Set range config via ludus CLI
echo "Setting range config..."
ludus_cmd -r "$RANGE_NAME" range config set -f "$RANGE_DIR/range-config.yml" 2>&1
echo ""

# Step 2: Deploy via ludus CLI
echo "Deploying... (this takes 15-25 minutes)"
ludus_cmd -r "$RANGE_NAME" range deploy 2>&1
echo ""

# Step 3: Wait for deploy
echo "Waiting for deploy to complete..."
while true; do
    STATUS=$(ludus_cmd -r "$RANGE_NAME" range status --json 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('rangeState','UNKNOWN'))" 2>/dev/null || echo "UNKNOWN")
    echo "  Status: $STATUS ($(date +%H:%M:%S))"
    case "$STATUS" in
        SUCCESS) echo "Deploy complete!"; break ;;
        ERROR|FAILED)
            echo "ERROR: Deploy failed"
            ludus_cmd -r "$RANGE_NAME" range logs 2>&1 | tail -20
            exit 1
            ;;
    esac
    sleep 30
done

# Step 4: Resolve LME server IP
echo "Resolving LME server IP..."
LME_IP=$(ludus_cmd -r "$RANGE_NAME" range list --json 2>/dev/null | python3 -c "
import json,sys
data = json.load(sys.stdin)
vms = data if isinstance(data, list) else data.get('VMs', [])
# Handle both single range object and list of ranges
if isinstance(data, dict) and 'VMs' in data:
    vms = data['VMs']
elif isinstance(data, list) and data and 'VMs' in data[0]:
    vms = data[0]['VMs']
for vm in vms:
    name = vm.get('name','').lower()
    if 'lme' in name and 'server' in name and not vm.get('isRouter'):
        print(vm['ip']); break
" 2>/dev/null)

if [ -z "$LME_IP" ]; then
    echo "WARNING: Could not resolve LME server IP"
    exit 1
fi
echo "  LME server: $LME_IP"

# Step 5: Sync local code (if LME_REPO_URL is a local path)
if [ -n "$(rsync_source)" ] && [ -z "$UPGRADE_FROM_BRANCH" ]; then
    echo ""
    echo "=== Syncing local repo to server ==="
    sync_to_server "$LME_IP"

    echo "  Re-running install.sh with synced code..."
    $SSH_CMD "$SSH_USER@$LME_IP" "sudo bash -c '
        cd /opt/lme-install
        NON_INTERACTIVE=true AUTO_CREATE_ENV=true bash install.sh
    '" 2>&1 | tail -20
fi

# Step 6: Deploy monitors
echo ""
echo "Deploying disk monitors..."
bash "$SCRIPT_DIR/deploy-monitors.sh" "$LME_IP" "$SSH_USER" "$SSH_PASS"

# Step 7: Upgrade (if UPGRADE_FROM_BRANCH is set)
if [ -n "$UPGRADE_FROM_BRANCH" ]; then
    echo ""
    echo "=== Upgrade: $UPGRADE_FROM_BRANCH → $LME_BRANCH ==="
    sync_to_server "$LME_IP"

    echo "  Running install.sh (upgrade)..."
    $SSH_CMD "$SSH_USER@$LME_IP" "sudo bash -c '
        cd /opt/lme-install
        NON_INTERACTIVE=true AUTO_CREATE_ENV=true bash install.sh
    '" 2>&1 | tail -20

    echo "  Upgrade complete"
fi

echo ""
echo "=== Deploy complete ==="
echo "  Range: $RANGE_NAME"
echo "  LME server: $LME_IP"
echo "  Monitors: installed"
[ -n "$UPGRADE_FROM_BRANCH" ] && echo "  Upgraded: $UPGRADE_FROM_BRANCH → $LME_BRANCH"
echo ""
echo "Next: bash scripts/run-test.sh $RANGE_DIR"
