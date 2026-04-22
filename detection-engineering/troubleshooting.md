# LME Podman Troubleshooting Guide

## Podman Commands Hang (podman ps, podman exec, podman info)

### Symptoms

- `podman ps` hangs indefinitely — no output, no error
- `podman exec <container> <command>` never returns
- `systemctl status lme-*` shows all services as `active (running)` despite podman being unresponsive
- Container healthchecks stop updating

### Root Cause

Podman uses a SQLite database (`/var/lib/containers/storage/db.sql`) with file-level locking. When any `podman` process acquires the DB lock and hangs (e.g., a `podman exec` waiting on a slow command, or a healthcheck timing out), **every subsequent podman command queues behind it**.

Common triggers:
- A long-running `podman exec` that never completes (e.g., Ansible automation running `agent_control -l`)
- Healthcheck processes (`podman healthcheck run`) that fire while the lock is held
- Multiple concurrent `podman` calls from monitoring or automation tools

This creates a deadlock chain: the original stuck process holds the lock, healthchecks queue behind it, and all manual commands queue behind those.

### Diagnosis

**1. Check for stuck podman processes:**

```bash
ps aux | grep -E "podman (ps|info|exec|healthcheck)" | grep -v grep
```

**2. Identify the DB lock holders:**

```bash
sudo fuser /var/lib/containers/storage/db.sql
```

The **oldest PID** (lowest number) is typically the root cause.

**3. Identify what the oldest process is doing:**

```bash
ps -p <PID> -o pid,etime,args
```

### Resolution

**Step 1: Kill the stuck process**

```bash
sudo fuser /var/lib/containers/storage/db.sql
sudo kill <oldest_PID>
```

**Step 2: Kill cascaded stuck processes**

```bash
sudo kill $(ps aux | grep -E "podman (exec|healthcheck|ps|info)" | grep -v grep | awk '{print $2}') 2>/dev/null
```

**Step 3: Verify podman is responsive**

```bash
sudo timeout 5 podman ps --format "{{.Names}}: {{.Status}}"
```

If this returns container status within 5 seconds, podman is recovered.

### If Containers Stop After Clearing the Lock

Killing stuck processes may cascade to container stops (conmon exits). Restart services in dependency order:

```bash
# 1. Elasticsearch first
sudo systemctl restart lme-elasticsearch
sleep 10

# 2. Wazuh and Kibana (independent of each other)
sudo systemctl restart lme-wazuh-manager lme-kibana lme-elastalert2
sleep 15

# 3. Fleet last (requires Kibana)
sudo systemctl restart lme-fleet-server
sleep 5

# 4. Verify
sudo podman ps --format "table {{.Names}}\t{{.Status}}"
```

### Quick Recovery Script

```bash
#!/bin/bash
# Save as /usr/local/bin/lme-podman-recover.sh
set -e

echo "Checking for stuck podman processes..."
STUCK=$(ps aux | grep -E "podman (exec|healthcheck|ps|info)" | grep -v grep | awk '{print $2}')

if [ -z "$STUCK" ]; then
    echo "No stuck processes found."
    exit 0
fi

echo "Found stuck PIDs: $STUCK"
echo "Killing stuck processes..."
echo "$STUCK" | xargs kill 2>/dev/null
sleep 3

if timeout 5 podman ps > /dev/null 2>&1; then
    echo "Podman recovered. Containers still running."
    podman ps --format "table {{.Names}}\t{{.Status}}"
else
    echo "Containers stopped. Restarting LME services..."
    systemctl restart lme-elasticsearch
    sleep 10
    systemctl restart lme-wazuh-manager lme-kibana lme-elastalert2
    sleep 15
    systemctl restart lme-fleet-server
    sleep 5
    podman ps --format "table {{.Names}}\t{{.Status}}"
fi
```

### Prevention

- **Timeout-wrap all `podman exec` calls:**
  ```bash
  sudo timeout 30 podman exec lme-wazuh-manager /var/ossec/bin/agent_control -l
  ```
- **Avoid concurrent podman commands** during deployments or automation runs
- **Monitor with a canary check:**
  ```bash
  sudo timeout 5 podman ps || echo "PODMAN LOCK ISSUE"
  ```

---

## Elasticsearch Password Mismatch (401 Unauthorized)

### Symptoms

```
"type" : "security_exception",
"reason" : "unable to authenticate user [elastic] for REST request [/...]"
```

`extract_secrets.sh` returns a password but Elasticsearch rejects it.

### Root Cause

Running `install.sh` multiple times (e.g., repeated Ansible deployments) can regenerate the Elasticsearch internal keystore password while the podman secret store retains the old value. The password in podman's secret store drifts from what Elasticsearch actually has.

### Resolution

LME provides `password_management.sh` for credential rotation:

```bash
# List available users
sudo -i ${CLONE_DIRECTORY}/scripts/password_management.sh -l

# Reset a specific user's password
sudo -i ${CLONE_DIRECTORY}/scripts/password_management.sh -s
```

If `password_management.sh` is unavailable, reset directly via the ES API:

```bash
# Get current (stale) password from vault
source /opt/lme-install/scripts/extract_secrets.sh -q

# Reset via container
sudo podman exec lme-elasticsearch elasticsearch-reset-password -u elastic --batch
```

Or via the `_security` API if you know any valid credential:

```bash
curl -sk -X POST -u "elastic:CURRENT_PASSWORD" \
  https://localhost:9200/_security/user/elastic/_password \
  -H 'Content-Type: application/json' \
  -d '{"password": "NEW_PASSWORD_HERE"}'
```

See the official LME docs for full details:
- [Password Management](https://cisagov.github.io/lme-docs/docs/markdown/reference/passwords/)
- [Troubleshooting](https://cisagov.github.io/lme-docs/docs/markdown/reference/troubleshooting/)

### Verify

```bash
curl -sk -u "elastic:<NEW_PASSWORD>" https://localhost:9200/_cluster/health?pretty
```

Expected: `"status" : "green"`

### Note

The podman lock deadlock issue (documented above) is **not covered in the official LME troubleshooting docs** as of 2026-04-01. The official docs cover container restarts, dependent container removal, memory tuning, and basic password reset — but not the SQLite lock cascade failure mode.
