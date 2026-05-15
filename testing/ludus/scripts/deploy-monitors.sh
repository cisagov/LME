#!/usr/bin/env bash
# deploy-monitors.sh — Deploy disk monitor + audit check to all LME servers in a range
#
# Usage: bash deploy-monitors.sh <lme-server-ip> [ssh-user] [ssh-pass]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LME_IP="${1:?Usage: deploy-monitors.sh <lme-server-ip>}"
SSH_USER="${2:-localuser}"
SSH_PASS="${3:-password}"
SSH_CMD="sshpass -p $SSH_PASS ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

echo "Deploying monitors to $LME_IP..."

# Copy disk monitor
sshpass -p "$SSH_PASS" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
    "$SCRIPT_DIR/lme_disk_monitor.sh" "$SSH_USER@$LME_IP:/home/$SSH_USER/"

$SSH_CMD "$SSH_USER@$LME_IP" "sudo bash -c '
cp /home/$SSH_USER/lme_disk_monitor.sh /opt/lme/scripts/lme_disk_monitor.sh 2>/dev/null || \
cp /home/$SSH_USER/lme_disk_monitor.sh /opt/lme-install/scripts/lme_disk_monitor.sh 2>/dev/null
chmod +x /opt/lme/scripts/lme_disk_monitor.sh 2>/dev/null || true
chmod +x /opt/lme-install/scripts/lme_disk_monitor.sh 2>/dev/null || true

# Install cron (idempotent)
SCRIPT=\$(ls /opt/lme/scripts/lme_disk_monitor.sh /opt/lme-install/scripts/lme_disk_monitor.sh 2>/dev/null | head -1)
(crontab -l 2>/dev/null | grep -v lme_disk_monitor; echo \"* * * * * \$SCRIPT >> /var/log/lme-disk-monitor.log 2>&1\") | crontab -
echo \"Monitor installed: \$SCRIPT\"
crontab -l | grep disk_monitor
'"

echo "Done — disk monitor active on $LME_IP"
