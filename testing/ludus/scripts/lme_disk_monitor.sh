#!/usr/bin/env bash
# @decision DEC-DISK-001: Automated disk monitor and cleanup for LME servers.
# Runs via cron every minute. When disk usage exceeds THRESHOLD (default 60%),
# performs tiered cleanup: Wazuh vd cache -> old ES indices -> container images -> apt cache.
# ES index cleanup uses age-based deletion (configurable retention).
#
# Usage:
#   sudo bash lme_disk_monitor.sh                    # run once
#   # crontab entry (runs every minute):
#   * * * * * /opt/lme/scripts/lme_disk_monitor.sh >> /var/log/lme-disk-monitor.log 2>&1
#
# Configuration via environment variables:
#   DISK_THRESHOLD=60        # percent usage to trigger cleanup
#   ES_RETENTION_DAYS=1             # delete .ds-metrics/.ds-logs indices older than N days
#   WAZUH_ALERT_RETENTION_DAYS=3    # delete wazuh-alerts indices older than N days
#   WAZUH_ALERT_MAX_MB=500          # force delete wazuh-alerts older than 1 day if total > this
#   SECURITY_ALERT_MAX_MB=500       # delete oldest security alerts if index > this
#   DRY_RUN=1                       # set to 1 to log actions without executing

set -euo pipefail

DISK_THRESHOLD="${DISK_THRESHOLD:-60}"
ES_RETENTION_DAYS="${ES_RETENTION_DAYS:-1}"
WAZUH_ALERT_RETENTION_DAYS="${WAZUH_ALERT_RETENTION_DAYS:-3}"
WAZUH_ALERT_MAX_MB="${WAZUH_ALERT_MAX_MB:-500}"
SECURITY_ALERT_MAX_MB="${SECURITY_ALERT_MAX_MB:-500}"
DRY_RUN="${DRY_RUN:-0}"
LOG_TAG="lme-disk-monitor"

PODMAN=$(command -v podman 2>/dev/null || echo "/nix/var/nix/profiles/default/bin/podman")

log() { echo "$(date -Iseconds) [$LOG_TAG] $*"; }

# ── Get current disk usage ────────────────────────────────────────────────────
USAGE=$(df / --output=pcent | tail -1 | tr -dc '0-9')
log "Disk usage: ${USAGE}% (threshold: ${DISK_THRESHOLD}%)"

# ── Tier 5: fstrim — always run unconditionally ───────────────────────────────
# fstrim reclaims deleted blocks from the QCOW2 image on the Proxmox host.
# This is free (no data loss, instant, no service impact) and critically
# important: the Proxmox host disk fills up from bloated QCOW2 images even
# when the guest VM disk usage is low (22-34%). Running fstrim inside the
# guest tells the hypervisor which blocks are unused so it can shrink the image.
# We run this BEFORE the threshold check so it always executes regardless of
# guest disk usage. @decision DEC-DISK-002
log "Tier 5: fstrim (reclaim space on Proxmox host — always runs)"
if [ "$DRY_RUN" = "0" ]; then
    TRIMMED=$(fstrim -av / 2>/dev/null | grep -oP '[\d.]+ [A-Za-z]+(?= trimmed)' || echo "0")
    log "Tier 5: Trimmed $TRIMMED"
fi

if [ "$USAGE" -lt "$DISK_THRESHOLD" ]; then
    log "Disk usage ${USAGE}% below threshold ${DISK_THRESHOLD}% -- no further cleanup needed"
    exit 0
fi

log "WARNING: Disk usage ${USAGE}% exceeds ${DISK_THRESHOLD}% -- starting tiered cleanup"

# ── Tier 1: Wazuh vulnerability detection cache ──────────────────────────────
VD_BASE=$($PODMAN volume inspect lme_wazuh_queue --format '{{.Mountpoint}}' 2>/dev/null || echo "")
if [ -n "$VD_BASE" ] && [ -d "$VD_BASE/vd_updater/tmp" ]; then
    TMP_SIZE=$(du -sm "$VD_BASE/vd_updater/tmp" 2>/dev/null | cut -f1 || echo 0)
    if [ "$TMP_SIZE" -gt 1000 ]; then
        log "Tier 1: Clearing Wazuh vd_updater/tmp (${TMP_SIZE}MB)"
        if [ "$DRY_RUN" = "0" ]; then
            rm -rf "${VD_BASE}/vd_updater/tmp/"*
        fi
    fi

    FEED_SIZE=$(du -sm "$VD_BASE/vd/feed" 2>/dev/null | cut -f1 || echo 0)
    if [ "$FEED_SIZE" -gt 5000 ]; then
        log "Tier 1: Clearing Wazuh vd/feed (${FEED_SIZE}MB) -- will auto-redownload"
        if [ "$DRY_RUN" = "0" ]; then
            systemctl stop lme-wazuh-manager 2>/dev/null || true
            rm -rf "${VD_BASE}/vd/feed/"* "${VD_BASE}/vd/delayed/"* "${VD_BASE}/vd_updater/rocksdb/"*
            systemctl start lme-wazuh-manager 2>/dev/null || true
        fi
    fi
fi

# Recheck
USAGE=$(df / --output=pcent | tail -1 | tr -dc '0-9')
log "After Tier 1: ${USAGE}%"
[ "$USAGE" -lt "$DISK_THRESHOLD" ] && { log "Below threshold -- done"; exit 0; }

# ── Tier 2: Old Elasticsearch indices ─────────────────────────────────────────
log "Tier 2: Checking ES indices for age-based cleanup"

if [ -f /opt/lme-install/scripts/extract_secrets.sh ]; then
    source /opt/lme-install/scripts/extract_secrets.sh -q 2>/dev/null || true
fi

CA_CERT=$($PODMAN volume inspect lme_certs --format '{{.Mountpoint}}' 2>/dev/null)/ca/ca.crt
ES_URL="https://localhost:9200"

if [ -n "${elastic:-}" ]; then
    METRICS_CUTOFF=$(date -d "-${ES_RETENTION_DAYS} days" +%Y.%m.%d 2>/dev/null || echo "")
    WAZUH_CUTOFF=$(date -d "-${WAZUH_ALERT_RETENTION_DAYS} days" +%Y.%m.%d 2>/dev/null || echo "")
    WAZUH_FORCE_CUTOFF=$(date -d "-1 days" +%Y.%m.%d 2>/dev/null || echo "")

    if [ -n "$METRICS_CUTOFF" ]; then
        # 2a: Delete .ds-metrics and .ds-logs older than 1 day (NOT security alerts)
        INDICES=$(curl -sk --cacert "$CA_CERT" -u "elastic:${elastic}" \
            "${ES_URL}/_cat/indices?h=index&s=index" 2>/dev/null | \
            grep -E '^\.(ds-(metrics|logs)-)' | \
            grep -v 'security\|alert' || true)

        for idx in $INDICES; do
            IDX_DATE=$(echo "$idx" | grep -oP '\d{4}\.\d{2}\.\d{2}' || echo "")
            if [ -n "$IDX_DATE" ] && [[ "$IDX_DATE" < "$METRICS_CUTOFF" ]]; then
                SIZE=$(curl -sk --cacert "$CA_CERT" -u "elastic:${elastic}" \
                    "${ES_URL}/_cat/indices/${idx}?h=store.size" 2>/dev/null | tr -d ' ')
                log "Tier 2a: Deleting old index $idx (${SIZE}, older than ${ES_RETENTION_DAYS}d)"
                if [ "$DRY_RUN" = "0" ]; then
                    curl -sk --cacert "$CA_CERT" -u "elastic:${elastic}" \
                        -X DELETE "${ES_URL}/${idx}" >/dev/null 2>&1
                fi
            fi
        done

        # 2b: Delete wazuh-alerts older than 3 days
        #     OR older than 1 day if total wazuh-alerts exceed WAZUH_ALERT_MAX_MB
        WAZUH_TOTAL_BYTES=$(curl -sk --cacert "$CA_CERT" -u "elastic:${elastic}" \
            "${ES_URL}/_cat/indices/wazuh-alerts-*?h=store.size&bytes=b" 2>/dev/null | \
            awk '{s+=$1} END {print s+0}' || echo 0)
        WAZUH_TOTAL_MB=$((WAZUH_TOTAL_BYTES / 1048576))
        log "Tier 2b: Wazuh alerts total: ${WAZUH_TOTAL_MB}MB (max: ${WAZUH_ALERT_MAX_MB}MB)"

        # Pick cutoff: 3 days normally, 1 day if oversized
        if [ "$WAZUH_TOTAL_MB" -gt "$WAZUH_ALERT_MAX_MB" ]; then
            EFFECTIVE_WAZUH_CUTOFF="$WAZUH_FORCE_CUTOFF"
            log "Tier 2b: Wazuh alerts oversized — using 1-day cutoff"
        else
            EFFECTIVE_WAZUH_CUTOFF="$WAZUH_CUTOFF"
        fi

        WAZUH_INDICES=$(curl -sk --cacert "$CA_CERT" -u "elastic:${elastic}" \
            "${ES_URL}/_cat/indices/wazuh-alerts-*?h=index" 2>/dev/null || true)
        for idx in $WAZUH_INDICES; do
            IDX_DATE=$(echo "$idx" | grep -oP '\d{4}\.\d{2}\.\d{2}' || echo "")
            if [ -n "$IDX_DATE" ] && [[ "$IDX_DATE" < "$EFFECTIVE_WAZUH_CUTOFF" ]]; then
                log "Tier 2b: Deleting wazuh index $idx (older than cutoff $EFFECTIVE_WAZUH_CUTOFF)"
                if [ "$DRY_RUN" = "0" ]; then
                    curl -sk --cacert "$CA_CERT" -u "elastic:${elastic}" \
                        -X DELETE "${ES_URL}/${idx}" >/dev/null 2>&1
                fi
            fi
        done

        # 2c: Trim security alerts if index exceeds SECURITY_ALERT_MAX_MB
        SEC_BYTES=$(curl -sk --cacert "$CA_CERT" -u "elastic:${elastic}" \
            "${ES_URL}/_cat/indices/.internal.alerts-security*?h=store.size&bytes=b" 2>/dev/null | \
            awk '{s+=$1} END {print s+0}' || echo 0)
        SEC_MB=$((SEC_BYTES / 1048576))
        log "Tier 2c: Security alerts: ${SEC_MB}MB (max: ${SECURITY_ALERT_MAX_MB}MB)"
        if [ "$SEC_MB" -gt "$SECURITY_ALERT_MAX_MB" ]; then
            log "Tier 2c: Security alerts oversized — deleting oldest 50%"
            if [ "$DRY_RUN" = "0" ]; then
                TOTAL_DOCS=$(curl -sk --cacert "$CA_CERT" -u "elastic:${elastic}" \
                    "${ES_URL}/.internal.alerts-security.alerts-default-000001/_count" 2>/dev/null | \
                    grep -oP '"count":\K\d+' || echo 0)
                HALF=$((TOTAL_DOCS / 2))
                curl -sk --cacert "$CA_CERT" -u "elastic:${elastic}" \
                    -X POST "${ES_URL}/.internal.alerts-security.alerts-default-000001/_delete_by_query" \
                    -H "Content-Type: application/json" \
                    -d "{\"query\":{\"range\":{\"@timestamp\":{\"lt\":\"now-1d\"}}},\"max_docs\":${HALF}}" \
                    >/dev/null 2>&1
                log "Tier 2c: Deleted up to $HALF oldest security alerts (older than 1 day)"
            fi
        fi
    fi
fi

# Recheck
USAGE=$(df / --output=pcent | tail -1 | tr -dc '0-9')
log "After Tier 2: ${USAGE}%"
[ "$USAGE" -lt "$DISK_THRESHOLD" ] && { log "Below threshold -- done"; exit 0; }

# ── Tier 3: Container image cleanup ──────────────────────────────────────────
log "Tier 3: Pruning unused container images"
if [ "$DRY_RUN" = "0" ]; then
    $PODMAN image prune -af 2>/dev/null | tail -3
fi

# Recheck
USAGE=$(df / --output=pcent | tail -1 | tr -dc '0-9')
log "After Tier 3: ${USAGE}%"
[ "$USAGE" -lt "$DISK_THRESHOLD" ] && { log "Below threshold -- done"; exit 0; }

# ── Tier 4: System cleanup ────────────────────────────────────────────────────
log "Tier 4: System cleanup (apt cache, journal)"
if [ "$DRY_RUN" = "0" ]; then
    apt-get clean 2>/dev/null || true
    journalctl --vacuum-size=100M 2>/dev/null || true
fi

USAGE=$(df / --output=pcent | tail -1 | tr -dc '0-9')
log "Final: ${USAGE}%"
if [ "$USAGE" -ge "$DISK_THRESHOLD" ]; then
    log "ALERT: Still above threshold after all cleanup tiers!"
fi
