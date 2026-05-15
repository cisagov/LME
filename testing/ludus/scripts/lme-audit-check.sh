#!/usr/bin/env bash
# lme-audit-check.sh — Poll all LME servers from Ludus inventory
set -uo pipefail  # no -e: SSH failures must not abort the script

if [ -z "${LUDUS_URL:-}" ] || [ -z "${LUDUS_API_KEY:-}" ]; then
    if [ -f "$HOME/.ludus/config" ]; then
        LUDUS_URL=$(grep 'url' "$HOME/.ludus/config" | awk '{print $3}')
        LUDUS_API_KEY=$(grep 'api_key' "$HOME/.ludus/config" | awk '{print $3}')
    else
        echo "ERROR: Set LUDUS_URL and LUDUS_API_KEY or create ~/.ludus/config"
        exit 1
    fi
fi

SSH_USER="${SSH_USER:-localuser}"
SSH_PASS="${SSH_PASS:-password}"
SSH_CMD="sshpass -p $SSH_PASS ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o LogLevel=ERROR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=============================================="
echo "  LME Disk Monitor Audit"
echo "  $(date -Iseconds)"
echo "=============================================="
echo ""

LME_SERVERS=$(curl -sk "$LUDUS_URL/api/v2/range/all" -H "X-API-KEY: $LUDUS_API_KEY" 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
if not isinstance(data, list): data = [data]
for r in data:
    rid = r.get('rangeID','')
    state = r.get('rangeState','')
    rnum = r.get('rangeNumber', 0)
    for vm in r.get('VMs',[]):
        name = vm.get('name','')
        ip = vm.get('ip','')
        if 'lme-server' not in name.lower(): continue
        if not ip or ip == 'null': ip = f'10.{rnum}.10.10'
        print(f'{ip}|{name}|{rid}|{state}')
" 2>/dev/null)

if [ -z "$LME_SERVERS" ]; then
    echo "No LME servers found."
    exit 1
fi

PASS=0
FAIL=0

# Read server list into an array first to avoid SSH consuming stdin when using
# pipe or fd-redirect patterns. The fd3/here-string approach breaks when SSH is
# invoked via a variable ($SSH_CMD) because the variable expansion launches SSH
# without an explicit </dev/null, causing SSH to slurp the remaining lines of
# the here-string as keyboard input. Array iteration sidesteps this entirely.
mapfile -t SERVER_LIST <<< "$LME_SERVERS"

for entry in "${SERVER_LIST[@]}"; do
    [ -z "$entry" ] && continue
    IFS='|' read -r ip name range_id state <<< "$entry"

    echo "-- $name ($ip) -- range: $range_id STATE: [$state]"

    # Redirect stdin explicitly so SSH cannot consume it even when called via
    # variable expansion. Capture combined stdout+stderr for diagnostics.
    SSH_ERR=$($SSH_CMD "$SSH_USER@$ip" 'echo ok' </dev/null 2>&1)
    SSH_RC=$?
    if [ "$SSH_RC" -ne 0 ]; then
        echo -e "  ${RED}SKIP: SSH unreachable${NC}"
        echo "    user:    $SSH_USER"
        echo "    target:  $ip:22"
        echo "    error:   $SSH_ERR"
        # Quick diagnostics
        if echo "$SSH_ERR" | grep -qi "connection refused"; then
            echo "    hint:    sshd may not be running on the target"
        elif echo "$SSH_ERR" | grep -qi "connection timed out\|timed out"; then
            echo "    hint:    VM may be powered off or IP unreachable (check WireGuard/routing)"
        elif echo "$SSH_ERR" | grep -qi "permission denied"; then
            echo "    hint:    wrong username or password"
        elif echo "$SSH_ERR" | grep -qi "host key"; then
            echo "    hint:    stale host key — run: ssh-keygen -R $ip"
        elif ! command -v sshpass >/dev/null 2>&1; then
            echo "    hint:    sshpass not installed — run: apt install sshpass"
        fi
        FAIL=$((FAIL + 1))
        echo ""
        continue
    fi

    CRON=$($SSH_CMD "$SSH_USER@$ip" 'sudo crontab -l 2>/dev/null | grep lme_disk_monitor' </dev/null 2>/dev/null || echo "")
    [ -n "$CRON" ] && echo -e "  cron:   ${GREEN}OK${NC}" || { echo -e "  cron:   ${RED}MISSING${NC}"; FAIL=$((FAIL + 1)); }

    SCRIPT=$($SSH_CMD "$SSH_USER@$ip" 'ls /opt/lme/scripts/lme_disk_monitor.sh /opt/lme-install/scripts/lme_disk_monitor.sh 2>/dev/null | head -1 || echo MISSING' </dev/null 2>/dev/null)
    echo "$SCRIPT" | grep -q MISSING && { echo -e "  script: ${RED}MISSING${NC}"; FAIL=$((FAIL + 1)); } || echo -e "  script: ${GREEN}OK${NC}"

    LOG=$($SSH_CMD "$SSH_USER@$ip" 'sudo tail -1 /var/log/lme-disk-monitor.log 2>/dev/null || echo NOLOG' </dev/null 2>/dev/null)
    [ "$LOG" = "NOLOG" ] && echo -e "  log:    ${YELLOW}NO LOG YET${NC}" || echo "  log:    $LOG"

    DISK=$($SSH_CMD "$SSH_USER@$ip" 'df -h / --output=pcent,avail | tail -1' </dev/null 2>/dev/null)
    DISK_PCT=$(echo "$DISK" | tr -dc '0-9' | head -c3)
    if [ "${DISK_PCT:-0}" -gt 60 ]; then
        echo -e "  disk:  ${RED}$DISK${NC}"
    elif [ "${DISK_PCT:-0}" -gt 40 ]; then
        echo -e "  disk:  ${YELLOW}$DISK${NC}"
    else
        echo -e "  disk:  ${GREEN}$DISK${NC}"
    fi

    CTR=$($SSH_CMD "$SSH_USER@$ip" 'sudo podman ps -q 2>/dev/null | wc -l' </dev/null 2>/dev/null)
    if [ "${CTR:-0}" -ge 11 ]; then
        echo -e "  containers: ${GREEN}$CTR${NC}"
    elif [ "${CTR:-0}" -ge 5 ]; then
        echo -e "  containers: ${YELLOW}$CTR${NC}"
    else
        echo -e "  containers: ${RED}$CTR${NC}"
    fi

    PASS=$((PASS + 1))
done

echo "=============================================="
if [ "$FAIL" -gt 0 ]; then
    echo -e "  Servers: $((PASS + FAIL))  ${GREEN}OK: $PASS${NC}  ${RED}ISSUES: $FAIL${NC}"
else
    echo -e "  Servers: $((PASS + FAIL))  ${GREEN}OK: $PASS${NC}  Issues: 0"
fi
echo "=============================================="
