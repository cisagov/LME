#!/usr/bin/env bash
# @decision DEC-FSTRIM-001: Run fstrim from the Ludus host against all VMs via SSH
# rather than relying on in-VM cron. Guest VMs at 20% disk can still bloat QCOW2
# images on the host because the hypervisor doesn't know which guest blocks are free
# until fstrim sends TRIM/DISCARD commands. Running centrally ensures coverage of
# ALL VMs (not just LME servers) and avoids per-VM cron maintenance.
#
# ludus-fstrim.sh — Reclaim QCOW2 disk space on Proxmox by running fstrim on all Ludus VMs
#
# fstrim tells the hypervisor which guest blocks are free so QCOW2 images shrink.
# Safe for forensic environments — fstrim does NOT modify file contents, only
# marks freed blocks as reusable at the storage layer.
#
# Usage:
#   bash ludus-fstrim.sh              # run once
#   bash ludus-fstrim.sh --install    # install as cron (every 5 min)
#   bash ludus-fstrim.sh --uninstall  # remove cron
#
# Requires: sshpass, curl, python3, LUDUS_URL + LUDUS_API_KEY (or ~/.ludus/config)

set -uo pipefail

SSH_USER="${SSH_USER:-localuser}"
SSH_PASS="${SSH_PASS:-password}"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5"
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

# ── Install / uninstall cron ──────────────────────────────────────────────────
if [ "${1:-}" = "--install" ]; then
    CRON_LINE="*/5 * * * * $SCRIPT_PATH >> /var/log/ludus-fstrim.log 2>&1"
    (crontab -l 2>/dev/null | grep -v ludus-fstrim; echo "$CRON_LINE") | crontab -
    echo "Installed: runs every 5 minutes"
    echo "  $CRON_LINE"
    echo "  Log: /var/log/ludus-fstrim.log"
    exit 0
fi

if [ "${1:-}" = "--uninstall" ]; then
    (crontab -l 2>/dev/null | grep -v ludus-fstrim) | crontab -
    echo "Uninstalled ludus-fstrim cron job"
    exit 0
fi

# ── Discover VMs ──────────────────────────────────────────────────────────────
if [ -z "${LUDUS_URL:-}" ] || [ -z "${LUDUS_API_KEY:-}" ]; then
    if [ -f "$HOME/.ludus/config" ]; then
        LUDUS_URL=$(grep 'url' "$HOME/.ludus/config" | awk '{print $3}')
        LUDUS_API_KEY=$(grep 'api_key' "$HOME/.ludus/config" | awk '{print $3}')
    else
        echo "ERROR: Set LUDUS_URL and LUDUS_API_KEY or create ~/.ludus/config"
        exit 1
    fi
fi

VM_IPS=$(curl -sk "$LUDUS_URL/api/v2/range/all" -H "X-API-KEY: $LUDUS_API_KEY" 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
if not isinstance(data, list): data = [data]
for r in data:
    for vm in r.get('VMs', []):
        if vm.get('isRouter'): continue
        ip = vm.get('ip', '')
        if not ip or ip == 'null': continue
        print(ip)
" 2>/dev/null)

if [ -z "$VM_IPS" ]; then
    echo "$(date -Iseconds) No VMs found"
    exit 0
fi

VM_COUNT=$(echo "$VM_IPS" | wc -l)
echo "$(date -Iseconds) Running fstrim on $VM_COUNT VMs..."

# ── Run fstrim on all VMs in parallel ─────────────────────────────────────────
for ip in $VM_IPS; do
    (
        result=$(sshpass -p "$SSH_PASS" ssh $SSH_OPTS "$SSH_USER@$ip" 'sudo fstrim -av / 2>&1' </dev/null 2>&1)
        if [ $? -eq 0 ]; then
            echo "  $ip: $result"
        fi
    ) &
done

wait
echo "$(date -Iseconds) Done"
