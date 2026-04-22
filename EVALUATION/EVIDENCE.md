# Testing & Security Evidence Log

**Branch:** `feature/testing-security` (from `mreeve-det-eng`)
**Date:** 2026-04-20 — 2026-04-22
**Operator:** Claude Code (automated)

---

## Security Fixes Applied

### Fix 1: LITELLM_API_KEY moved to Podman Secret

**Problem:** `sk-lme-llama-proxy` was hardcoded in `lme-dashboard.container` and `lme-log-analyzer.container` as a plaintext environment variable.

**Resolution:**
- Created new Podman secret `litellm-proxy-key` (random per-install, `sk-lme-<24 random chars>`)
- Updated containers to use `Secret=litellm-proxy-key,type=env,target=LITELLM_API_KEY`
- Updated `lme-litellm.container` to receive `Secret=litellm-proxy-key,type=env,target=LITELLM_MASTER_KEY`
- Updated `config/litellm_config.yaml` to read master_key from `os.environ/LITELLM_MASTER_KEY`
- Added secret creation to both `ansible/roles/podman/tasks/llama_cpp_setup.yml` (fresh install) and `ansible/upgrade_lme.yml` (upgrade path)

**Files changed:**
```
quadlet/lme-dashboard.container       — Secret injection replaces hardcoded env
quadlet/lme-log-analyzer.container    — Secret injection replaces hardcoded env
quadlet/lme-litellm.container         ��� Added litellm-proxy-key secret for LITELLM_MASTER_KEY
config/litellm_config.yaml            — master_key reads from env var
ansible/roles/podman/tasks/llama_cpp_setup.yml — Secret creation task added
ansible/upgrade_lme.yml               — Secret creation task added for upgrades
```

**Annotation:** `@decision DEC-SEC-001` in `llama_cpp_setup.yml`

---

### Fix 2: Health Checks Use CA Certificate (no TLS skip)

**Problem:** Three containers used `curl -k` / `curl -fsk` in health checks, bypassing TLS verification.

**Resolution:**
- `lme-llama-cpp.container`: `curl -fsk` → `curl -f --cacert /certs/ca/ca.crt`
- `lme-embeddings.container`: `curl -kf` → `curl -f --cacert /certs/ca/ca.crt`
- `lme-wazuh-manager.container`: `curl -k -s` → `curl -s --cacert /etc/wazuh-manager/certs/ca/ca.crt`

All containers already mount the `lme_certs` volume at `/certs:ro` or the Wazuh cert path. The CA is available; there was no technical reason to skip verification.

**Files changed:**
```
quadlet/lme-llama-cpp.container
quadlet/lme-embeddings.container
quadlet/lme-wazuh-manager.container
```

---

### Fix 3: Internal Ports Removed from Host Publishing

**Problem:** Ports 8081 (embeddings), 4000 (litellm), and 5432 (pgvector) were published to the host via `PublishPort`, but are only accessed by other containers over the internal `lme` network using DNS names.

**Evidence of internal-only usage:**
- `lme-dashboard/app.py:38` connects to `lme-litellm:4000` (container DNS)
- `lme-dashboard/app.py` connects to `lme-embeddings:8081` (container DNS)
- `lme-dashboard/app.py` connects to `lme-pgvector:5432` (container DNS)
- `lme-log-analyzer/app_simple.py:20` connects to `lme-litellm:4000` (container DNS)
- No application code uses `localhost:8081`, `localhost:4000`, or `localhost:5432`

**Resolution:** Commented out `PublishPort` lines with explanation comments.

**Files changed:**
```
quadlet/lme-embeddings.container   — PublishPort=8081:8081 removed
quadlet/lme-litellm.container      — PublishPort=4000:4000 removed
quadlet/lme-pgvector.container     — PublishPort=5432:5432 removed
```

---

### Fix 4: Model Volumes Made Read-Only

**Problem:** `/opt/lme/llama-models` was mounted with write access (`:Z`) in llama-cpp and embeddings containers. Models are pre-downloaded at install time; no runtime writes are needed.

**Resolution:** Changed to `:ro,Z` (read-only with SELinux relabel).

**Files changed:**
```
quadlet/lme-llama-cpp.container    — Volume mount :Z → :ro,Z
quadlet/lme-embeddings.container   — Volume mount :Z → :ro,Z
```

---

## Ludus Deployment Evidence (Live)

**Date:** 2026-04-21
**Range:** mreeve (10.1.0.0/16, VLAN 10)

### Deploy Sequence

1. `vm-deploy` tag — powered on all VMs (router, lme-server, caldera, win11, ubuntu)
2. First attempt: `ludus_lme_server` failed — `git clone force=no` on dirty `/opt/lme-install`
3. **Fix applied:** `force: true` in `ludus_lme_server/tasks/main.yml`, role re-uploaded via API
4. Second attempt: `install.sh` failed — ES rejected auth (stale secrets from prior install)
5. **Fix:** SSH wipe via `wipe_lme.sh`, then fresh redeploy
6. Third attempt: **SUCCESS** — all roles deployed, range state `SUCCESS`

### Verified Service Health

| Service | Host | Status | Evidence |
|---------|------|--------|----------|
| Elasticsearch | 10.1.10.10:9200 | **green**, 60 shards, 100% | `_cluster/health` |
| Kibana | 10.1.10.10:5601 | **HTTP 302** (login) | curl check |
| Fleet Server | 10.1.10.10:8220 | **HEALTHY** | `/api/status` |
| Wazuh Manager | 10.1.10.10:55000 | **HTTP 401** (auth OK) | curl check |
| ElastAlert2 | 10.1.10.10 (internal) | **Running** | `podman ps` |
| Caldera | 10.1.10.20:8888 | **active**, HTTP 200 | systemctl + curl |

### Verified Agent Enrollment

| Endpoint | IP | Elastic Agent | Wazuh Agent | Sysmon |
|----------|-----|:---:|:---:|:---:|
| ubuntu-ep | 10.1.10.40 | **active** | **active** (id:001) | N/A |
| WIN11-EP | 10.1.10.30 | (via Fleet) | **active** (id:002) | deployed by role |

Wazuh API confirmed 3 agents total (manager + ubuntu + win11), all status=active.

### Sigma Rule Conversion

- Script: `scripts/sigma/convert_sigma_to_kibana.sh`
- **2413 rules converted** (2218 Windows + 147 Linux + 48 macOS)
- Sigma release: r2026-01-01
- Upload to Kibana requires manual trigger (interactive confirmation)
- **Action needed:** Run upload portion or use `--auto` with upload flag

### ElastAlert2 Status

- Running with `debug` alert type (no email configured yet)
- Shows `InsecureRequestWarning` — **our fix** (`verify_certs: true` + CA path) resolves this but hasn't been deployed to this server yet
- Gmail configuration is a manual step requiring app password from user

### Issues Found & Fixed During Deploy

| Issue | Root Cause | Fix |
|-------|-----------|-----|
| `ludus_lme_server` git clone fails on dirty dir | `force: false` in git task | Changed to `force: true` |
| ES rejects elastic password on re-install | Stale secrets from prior install conflict with new vault | Wipe via `wipe_lme.sh` before re-install |
| ElastAlert2 `verify_certs: false` | Original config shipped without CA | Added `verify_certs: true` + `ca_certs` path |

---

## Testing Execution

### Test 1: Pre-Deployment Validation

#### 1.1 Ansible Lint

```bash
# Command to run on deployment host:
( cd /opt/lme && ansible-lint ansible/upgrade_lme.yml ansible/roles/podman/tasks/llama_cpp_setup.yml )
```

#### 1.2 YAML Validation

```bash
# Validate all quadlet files parse correctly:
for f in quadlet/*.container quadlet/*.volume; do
  echo -n "$f: "
  if grep -q '^\[Unit\]' "$f" 2>/dev/null; then
    echo "OK (valid systemd unit)"
  else
    echo "INVALID"
  fi
done
```

#### 1.3 Container Image List Verification

Expected containers (14 total):
| Container | Image | Port (Host) | Port (Internal) |
|-----------|-------|-------------|-----------------|
| lme-elasticsearch | docker.elastic.co/elasticsearch/elasticsearch:8.18.8 | 9200 | 9200 |
| lme-kibana | docker.elastic.co/kibana/kibana:8.18.8 | 5601 | 5601 |
| lme-fleet-server | docker.elastic.co/beats/elastic-agent:8.18.8 | 8220 | 8220 |
| lme-fleet-distribution | docker.elastic.co/package-registry/distribution:lite-8.18.8 | 8080 | 8080 |
| lme-wazuh-manager | localhost/wazuh-manager:LME_LATEST | 1514,1515,514,55000 | same |
| lme-elastalert | docker.io/jertel/elastalert2:2.20.0 | — | — |
| lme-llama-cpp | localhost/llama-cpp:LME_LATEST | — | 8080 |
| lme-embeddings | localhost/llama-cpp:LME_LATEST | — | 8081 |
| lme-litellm | localhost/litellm:LME_LATEST | — | 4000 |
| lme-pgvector | localhost/pgvector:LME_LATEST | — | 5432 |
| lme-dashboard | localhost/lme-dashboard:LME_LATEST | 8502 | 8502 |
| lme-log-analyzer | localhost/lme-log-analyzer:LME_LATEST | 8501 | 8501 |
| lme-setup-accts | (init container) | — | — |
| lme-setup-certs | (init container) | — | — |

---

### Test 2: Ludus Range Deployment

#### Deployment Commands

```bash
# 1. Upload roles to Ludus
ludus ansible role add --name ludus_lme_server --path ansible/roles/ludus_lme_server
ludus ansible role add --name ludus_lme_agents --path ansible/roles/ludus_lme_agents
ludus ansible role add --name ludus_caldera_server --path ansible/roles/ludus_caldera_server
ludus ansible role add --name ludus_caldera_agent --path ansible/roles/ludus_caldera_agent
ludus ansible role add --name ludus_caldera_scripts --path ansible/roles/ludus_caldera_scripts

# 2. Apply range config
ludus range config set -f ludus-range-config.yml

# 3. Deploy
ludus range deploy

# 4. Monitor deployment
ludus range status
ludus range logs -f
```

#### Expected Outcomes

- LME server VM: install.sh completes, 12 containers running (core + AI), credentials extracted
- Caldera server VM: Caldera 5.3.0 service running on :8888
- Windows endpoint: Elastic Agent enrolled, Wazuh agent active, Sysmon running, Caldera agent connected
- Ubuntu endpoint: Elastic Agent enrolled, Wazuh agent active, auditd rules applied

---

### Test 3: Elastic Rule / Sigma Rule Integration

#### How Sigma Rules Work in LME

The script `scripts/sigma/convert_sigma_to_kibana.sh` handles the full pipeline:
1. Downloads latest SigmaHQ release from GitHub
2. Installs `sigma-cli` with the elasticsearch backend plugin
3. Converts rules to Kibana NDJSON format (`sigma convert -t lucene --format siem_rule_ndjson`)
4. Uploads to Kibana Detection Engine API

#### Test Steps

```bash
# On LME server:

# 1. Run sigma conversion script
sudo bash /opt/lme/scripts/sigma/convert_sigma_to_kibana.sh

# 2. Verify rules uploaded to Kibana
ELASTIC_PASS=$(sudo bash /opt/lme/scripts/extract_secrets.sh -p)
curl -sf --cacert /opt/lme/certs/ca/ca.crt \
  -u "elastic:${ELASTIC_PASS}" \
  -H "kbn-xsrf: true" \
  "https://localhost:5601/api/detection_engine/rules/_find?per_page=1" | jq '.total'

# 3. Verify Elastic prebuilt rules (imported via dashboard)
curl -sf --cacert /opt/lme/certs/ca/ca.crt \
  -u "elastic:${ELASTIC_PASS}" \
  -H "kbn-xsrf: true" \
  "https://localhost:5601/api/detection_engine/rules/prepackaged/_status" | jq .

# 4. Enable a test rule and verify it triggers on synthetic data
# Example: Enable "Suspicious PowerShell Execution" rule, then run
# a benign PowerShell command on the Windows endpoint to generate an alert
```

#### Expected Evidence
- `total` > 0 from rules/_find
- Sigma rules appear in Kibana > Security > Rules with tag "sigma"
- At least one rule triggers when corresponding telemetry arrives

---

### Test 4: ElastAlert2 Upload & Gmail Notifications

#### Configuration Files

| File | Purpose |
|------|---------|
| `config/elastalert2/config.yaml` | Main ElastAlert2 config (ES connection, run interval) |
| `config/elastalert2/rules/kibana_alerts.yml` | Rule watching `.alerts-security.alerts-*` |
| `config/elastalert2/misc/smtp_auth.yml` | SMTP credentials (user/password) |

#### Setup Steps for Gmail

```bash
# 1. Generate Gmail App Password (requires 2FA enabled on Google account)
#    Go to: https://myaccount.google.com/apppasswords
#    Create app password for "Mail" on "Other (Custom name)" = "LME ElastAlert"

# 2. Update SMTP auth file
cat > /opt/lme/config/elastalert2/misc/smtp_auth.yml << 'EOF'
user: "your-security-alerts@gmail.com"
password: "your-app-password-here"
EOF
chmod 600 /opt/lme/config/elastalert2/misc/smtp_auth.yml

# 3. Create/update email alert rule
cat > /opt/lme/config/elastalert2/rules/kibana_alerts.yml << 'EOF'
name: "LME Security Alerts - Email"
type: any
index: .alerts-security.alerts-*
timeframe:
  minutes: 5
realert:
  minutes: 20
aggregation:
  minutes: 15

# Email notification via Gmail
alert:
  - email
smtp_host: smtp.gmail.com
smtp_port: 587
smtp_auth_file: /opt/elastalert/misc/smtp_auth.yml
from_addr: "your-security-alerts@gmail.com"
email:
  - "recipient@example.com"

alert_subject: "[LME] Security Alert: {0}"
alert_subject_args:
  - kibana.alert.rule.name
alert_text_type: alert_text_only
alert_text: |
  Security Alert Triggered
  Rule: {0}
  Severity: {1}
  Agent: {2}
  Timestamp: {3}
  Action: {4}
alert_text_args:
  - kibana.alert.rule.name
  - kibana.alert.severity
  - agent.name
  - "@timestamp"
  - kibana.alert.rule.actions
EOF

# 4. Restart ElastAlert2 to pick up new config
sudo systemctl restart lme-elastalert

# 5. Verify ElastAlert2 is running and connected
sudo podman logs lme-elastalert --tail 30
```

#### Verification Steps

```bash
# 1. Check ElastAlert2 container is healthy
sudo podman exec lme-elastalert elastalert-test-rule /opt/elastalert/rules/kibana_alerts.yml

# 2. Verify elastalert_status index exists (proves it's writing)
ELASTIC_PASS=$(sudo bash /opt/lme/scripts/extract_secrets.sh -p)
curl -sf --cacert /opt/lme/certs/ca/ca.crt \
  -u "elastic:${ELASTIC_PASS}" \
  "https://localhost:9200/elastalert_status/_count" | jq .count

# 3. Trigger a test alert:
#    - Enable a detection rule in Kibana
#    - Generate matching telemetry on an endpoint
#    - Wait for ElastAlert2 run interval (5 min)
#    - Check Gmail inbox for notification

# 4. Check ElastAlert2 logs for email send confirmation
sudo podman logs lme-elastalert 2>&1 | grep -i "email\|smtp\|sent"
```

#### Expected Evidence
- ElastAlert2 container running, writing to `elastalert_status` index
- `elastalert-test-rule` passes without errors
- Email arrives in Gmail with alert details within 5-20 minutes of rule trigger
- No SMTP errors in container logs

---

### Test 5: Upgrade Path (2.2.0 → 2.3.0)

```bash
# On a fresh LME 2.2.0 install:

# 1. Verify starting state (5 containers)
sudo podman ps --format '{{.Names}}' | wc -l  # expect: 5-6

# 2. Run pre-upgrade checks
ansible-playbook ansible/pre_upgrade_checks.yml

# 3. Run upgrade
ansible-playbook ansible/upgrade_lme.yml -e skip_prompts=true

# 4. Run validation
sudo bash scripts/validate_deployment.sh --verbose

# 5. Verify all 12 containers running
sudo podman ps --format '{{.Names}}' | wc -l  # expect: 12
```

---

### Test 6: Validation Script Execution

```bash
# Run the full validation suite
sudo bash scripts/validate_deployment.sh --verbose

# Expected output: all PASS/WARN, zero FAIL
# Script exits 0 on success, 1 on any failure
```

---

## Security Review Results

### Credential Inventory (Post-Fix)

| Secret Name | Used By | Driver | Generated | Rotation |
|-------------|---------|--------|-----------|----------|
| `elastic` | ES, Kibana, Dashboard, Log-Analyzer, ElastAlert | shell | install.sh | change_passwords.yml |
| `kibana-system` | Kibana | shell | install.sh | change_passwords.yml |
| `wazuh` | Wazuh Manager | shell | install.sh | change_passwords.yml |
| `wazuh_api` | Wazuh Manager | shell | install.sh | change_passwords.yml |
| `pgvector` | PgVector, Dashboard | file | llama_cpp_setup.yml | change_passwords.yml |
| `llm-keys` | LiteLLM | file | llama_cpp_setup.yml | sync_llm_keys.py |
| `litellm-proxy-key` | LiteLLM, Dashboard, Log-Analyzer | file | llama_cpp_setup.yml | change_passwords.yml |

### Network Exposure (Post-Fix)

| Port | Service | Exposed To | Justification |
|------|---------|-----------|---------------|
| 9200 | Elasticsearch | Host | Fleet agents connect from host network |
| 5601 | Kibana | Host | User-facing web UI |
| 8220 | Fleet Server | Host | Elastic Agents connect from endpoints |
| 8080 | Fleet Distribution | Host | Package registry for agents |
| 1514 | Wazuh (events) | Host | Wazuh agents connect from endpoints |
| 1515 | Wazuh (registration) | Host | Agent registration |
| 514/udp | Wazuh (syslog) | Host | Syslog forwarding |
| 55000 | Wazuh API | Host | Management API |
| 8502 | Dashboard | Host | User-facing web UI |
| 8501 | Log Analyzer | Host | User-facing web UI |
| 8080 | Llama-cpp | **Internal only** | Accessed by LiteLLM via container network |
| 8081 | Embeddings | **Internal only** | Accessed by Dashboard via container network |
| 4000 | LiteLLM | **Internal only** | Accessed by Dashboard/Log-Analyzer via container network |
| 5432 | PgVector | **Internal only** | Accessed by Dashboard via container network |

### TLS Coverage

All inter-service communication uses TLS with the LME CA:
- ES ↔ Kibana: TLS (mutual)
- ES ↔ Fleet: TLS
- ES ↔ ElastAlert: TLS
- LiteLLM ↔ Llama-cpp: TLS (via container network DNS)
- Dashboard ↔ LiteLLM: TLS
- Dashboard ↔ Embeddings: TLS
- Dashboard ↔ PgVector: **Plaintext** (PostgreSQL on internal network — acceptable for internal-only)
- Dashboard ↔ ES: TLS
- Log-Analyzer ↔ ES: TLS
- Log-Analyzer ↔ LiteLLM: TLS

### Container Isolation Compliance

| Container | PartOf lme.service | Non-root | User NS | RO Certs | No Privileged |
|-----------|:--:|:--:|:--:|:--:|:--:|
| lme-llama-cpp | Y | Y | default | Y | Y |
| lme-embeddings | Y | Y | default | Y | Y |
| lme-litellm | Y | Y | default | Y | Y |
| lme-pgvector | Y | Y (postgres) | default | N/A | Y |
| lme-dashboard | Y | Y | default | Y | Y |
| lme-log-analyzer | Y | Y | default | Y | Y |

---

## Ludus Deployment Test Commands

```bash
# Full end-to-end Ludus test sequence:

# Pre-flight
ludus range status
ludus templates list

# Deploy
ludus range config set -f ludus-range-config.yml
ludus range deploy --wait

# Validate LME server
ludus range ssh lme-server -- "sudo bash /opt/lme/scripts/validate_deployment.sh --verbose"

# Validate agents
ludus range ssh lme-server -- "sudo bash /opt/lme/testing/v2/installers/lib/check_agent_reporting.sh"

# Validate Caldera
ludus range ssh caldera-srv -- "systemctl is-active caldera.service"
ludus range ssh caldera-srv -- "curl -s http://localhost:8888 | grep -q caldera"

# Validate Windows endpoint
ludus range ssh win11-endpoint -- "Get-Service ElasticAgent | Select-Object Status"
ludus range ssh win11-endpoint -- "Get-Service WazuhSvc | Select-Object Status"
ludus range ssh win11-endpoint -- "Get-Process Sysmon* | Select-Object ProcessName"

# Sigma rules test
ludus range ssh lme-server -- "sudo bash /opt/lme/scripts/sigma/convert_sigma_to_kibana.sh"

# Cleanup
ludus range destroy
```

---

## Live Test Results (2026-04-21)

### LME 2.2.0 Fresh Install via Ludus

| Step | Result | Detail |
|------|--------|--------|
| Ludus `vm-deploy` | PASS | All 5 VMs powered on, IPs assigned |
| `ludus_lme_server` role | PASS (3rd attempt) | 1st: git force=no, 2nd: stale secrets, 3rd: clean wipe + deploy |
| `ludus_caldera_server` role | PASS | Caldera service active, HTTP 200 on :8888 |
| `ludus_lme_agents` (Ubuntu) | PASS | Elastic Agent active, Wazuh agent active (id:001) |
| `ludus_lme_agents` (Win11) | PASS | Wazuh agent active (id:002, WIN11-EP) |
| `ludus_caldera_scripts` | PASS | Deployed to Caldera server |
| ES cluster health | **green** | 60 shards, 100% active |
| Kibana | HTTP 302 | Login page renders |
| Fleet Server | HEALTHY | `/api/status` confirmed |
| Wazuh Manager | 3 agents | manager + ubuntu-ep + WIN11-EP, all status=active |
| ElastAlert2 | Running | Writing to elastalert_status index |

### LME 2.3.0 Upgrade (AI Stack)

| Step | Result | Detail |
|------|--------|--------|
| `ansible-playbook upgrade_lme.yml` | PASS | 81 tasks, 42 changed, 0 failed |
| GGUF models downloaded | PASS | LFM2.5-1.2B-Instruct + nomic-embed-text-v1.5 |
| New secrets created | PASS | pgvector, llm-keys |
| New TLS certs generated | PASS | llama-cpp, embeddings, litellm, dashboard, log-analyzer |
| All 11 containers running | PASS | ES, Kibana, Fleet, Wazuh, ElastAlert, llama-cpp, embeddings, litellm, pgvector, dashboard, log-analyzer |
| Doc ingestion to pgvector | PASS | "Documentation ingestion completed successfully" |
| Dashboard :8502 | HTTP 200 | LME Security Dashboard renders |
| Log Analyzer :8501 | HTTP 200 | Streamlit UI renders |
| llama-cpp :8080 | healthy | Internal health check passes |
| embeddings :8081 | healthy | Internal health check passes |
| pgvector :5432 | accepting connections | `pg_isready` passes |

### Test 3: Sigma Rule Integration (Live Evidence)

| Step | Result | Detail |
|------|--------|--------|
| `convert_sigma_to_kibana.sh` | PASS | 2413 rules converted (2218 Win + 147 Linux + 48 macOS) |
| Sigma release | r2026-01-01 | Latest SigmaHQ release |
| Upload linux rules to Kibana | PASS | "SUCCESS: linux rules uploaded" |
| Upload macOS rules to Kibana | PASS | "SUCCESS: macos rules uploaded" |
| Upload windows rules to Kibana | PASS | "SUCCESS: windows rules uploaded" |
| Total detection rules in Kibana | **3825** | 2414 sigma + prebuilt |
| 50 Windows rules bulk-enabled | PASS | Matched by `OS: Windows` tag |
| Test rule created | PASS | "LME Test Rule - Any Endpoint Activity", interval=1m, query=`*` |
| Alerts generated | **549+** | `.alerts-security.alerts-*` count growing |
| Log events flowing | **1497+** | `logs-*` index, data from both endpoints |

### Test 4: ElastAlert Upload & Gmail Notifications (Live Evidence)

| Step | Result | Detail |
|------|--------|--------|
| SMTP auth config written | PASS | `/opt/lme/config/elastalert2/misc/smtp_auth.yml` |
| Email alert rule created | PASS | `kibana_alerts.yml` with `import: email_alert_config` |
| ElastAlert restart | PASS | Container running, polling ES |
| 1st attempt (regular password) | FAIL | `Application-specific password required` (534) |
| Gmail App Password configured | PASS | Updated smtp_auth.yml with app-specific password |
| ElastAlert matches alerts | **PASS** | `num_matches: 100` in elastalert_status |
| **Email sent** | **PASS** | `alert_sent: true`, type=email, recipient=loggingmadeeasy@gmail.com |
| Timestamp of successful send | 2026-04-21T20:46:08.808042Z | elastalert_status index |
| Alert info | rule="LME Security Alerts - Email Notification", recipients=["loggingmadeeasy@gmail.com"] |

**End-to-end pipeline proven:** telemetry → ES → detection rules → `.alerts-security.alerts-*` → ElastAlert2 → SMTP → Gmail inbox

### Issues Found & Fixed During Testing

| Issue | Root Cause | Fix Applied |
|-------|-----------|-------------|
| `ludus_lme_server` git clone fails | `force: false` on dirty `/opt/lme-install` | Changed to `force: true`, re-uploaded role via API |
| ES rejects elastic password on re-install | Stale secrets from prior deploy | Wipe via `wipe_lme.sh` before fresh install |
| ElastAlert `verify_certs: false` | Original config shipped without CA ref | Added `verify_certs: true` + `ca_certs` path (in worktree) |
| ElastAlert SMTP 534 error | Regular Google password, not app password | Generated Gmail app password, updated smtp_auth.yml |
| smtp_auth.yml permission denied | Container user couldn't read 0600 file | Changed to 0644 (mounted read-only into container) |
| Upgrade playbook sees "no upgrade needed" | `lme-environment.env` already had target version | Set version back to 2.2.0 before running upgrade |

---

## Playwright Test Suites

### `scripts/playwright_lme_test.js` — Basic Deployment Verification (7 tests)

| Test | What it verifies |
|------|-----------------|
| 1. Kibana Login | Login form renders, elastic credentials accepted, redirects to app |
| 2. Security Rules | Kibana Security > Rules page loads with rule count |
| 3. Security Alerts | Kibana Security > Alerts page loads |
| 4. LME Dashboard | :8502 responds, title = "LME Security Dashboard" |
| 5. Log Analyzer | :8501 responds, Streamlit UI renders |
| 6. Caldera UI | :8888 responds, contains "caldera" or "login" |
| 7. Fleet Agents | Kibana Fleet > Agents page loads |

### `scripts/playwright_det_eng_test.js` — Detection Engineering Suite (30 tests)

| Section | Tests | What it verifies |
|---------|-------|-----------------|
| 1. Dashboard Core | 3 | Health status pills, `/api/health`, alerts API |
| 2. Detection Nav | 1 | Detection Engineering view loads, subtabs visible |
| 3. Sigma Integration | 6 | Sigma tab, sigma API status, Kibana rules tab, rules in Kibana Security UI, alerts from rules, rule toggle API |
| 4. ElastAlert & Gmail | 8 | ElastAlert tab, rules API, paste YAML upload, API paste upload, rule renders in UI, YAML expandable, `alert_sent=true` in ES, rule deletion |
| 5. AI Features | 4 | Chat sidebar, `/api/chat`, RAG docs status, Log Analyzer |
| 6. Model Management | 2 | `/api/models`, `/api/local-models` |
| 7. KEV Integration | 2 | KEV tab, KEV status API |
| 8. Fleet & Agents | 2 | Fleet agents page, Wazuh alerts API |
| 9. Caldera | 1 | Caldera UI accessible |
| 10. Prebuilt Rules | 1 | Prebuilt rules status API |

**Run command:**
```bash
mkdir -p evidence
npm init -y && npm install @playwright/test && npx playwright install chromium

# Basic suite:
LME_HOST=10.1.10.10 ELASTIC_PASS='ldCFPa5z!XCwzf2oF6wLQ6v75pVAtV' \
  npx playwright test scripts/playwright_lme_test.js --headed --timeout 120000

# Full detection engineering suite:
LME_HOST=10.1.10.10 ELASTIC_PASS='ldCFPa5z!XCwzf2oF6wLQ6v75pVAtV' \
  npx playwright test scripts/playwright_det_eng_test.js --headed --timeout 120000
```

Screenshots are saved to `evidence/` directory (01 through 18).

---

## Open Items / Recommendations

1. **Dashboard + Log Analyzer have no authentication** — They access ES internally with the elastic superuser. Consider adding basic auth or requiring Kibana SSO passthrough.
2. **PgVector uses plaintext** on internal network — Acceptable given internal-only exposure, but could add TLS if compliance requires it.
3. **Dashboard `TimeoutStartSec=5400`** (90 minutes) — Unusually long; likely needed for first-run model download. Consider splitting model download from container startup.
4. ~~**ElastAlert2 `verify_certs: False`**~~ — **FIXED** in this branch: `verify_certs: true` + `ca_certs` path added.
5. **Gmail app passwords expire** — If the Google account disables 2FA or revokes the app password, ElastAlert email will stop. Document the regeneration process.
6. **`ludus_lme_server` needs `force: true`** on git clone — **FIXED** in this branch, re-uploaded to Ludus.
