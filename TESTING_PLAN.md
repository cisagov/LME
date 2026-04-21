# Testing & Security Review Plan

**Branch:** `mreeve-det-eng` (post-merge of `llama-cpp-frontend`)
**Date:** 2026-04-20

This plan covers end-to-end validation of the merged branch, which now includes:
- **Ludus roles** (ludus_lme_server, ludus_lme_agents, ludus_caldera_server, ludus_caldera_agent, ludus_caldera_scripts)
- **AI/LLM stack** (llama-cpp, embeddings, litellm, pgvector, dashboard, log-analyzer)
- **Core LME stack** (elasticsearch, kibana, fleet-server, fleet-distribution, wazuh-manager, elastalert)

---

## 1. Testing

### 1.1 Pre-Deployment Validation

- [ ] Run `ansible-lint` on all playbooks and roles (`ansible/roles/ludus_*`, `ansible/upgrade_lme.yml`, `ansible/site.yml`)
- [ ] Run `yamllint` on all quadlet files and range configs
- [ ] Validate `ludus-range-config.yml` against Ludus JSON schema
- [ ] Verify `config/containers.txt` lists all expected images (6 core + 6 AI = 12 total images, 14 containers)
- [ ] Verify all Dockerfiles/Containerfiles build locally: `lme-dashboard`, `lme-log-analyzer`, `llama-cpp`, `litellm`, `pgvector`

### 1.2 Fresh Install (Ludus Deployment)

Deploy via Ludus using the merged range config:

- [ ] Build required Ludus templates: `ubuntu-24.04-x64-server-template`, `win11-22h2-x64-enterprise-template`
- [ ] Upload all 5 `ludus_*` roles via `ludus ansible role add`
- [ ] Apply `ludus-range-config.yml` via `ludus range config set`
- [ ] Deploy range: `ludus range deploy`
- [ ] Verify LME server role completes (install.sh + credential extraction)
- [ ] Verify Caldera server role completes (Go, Node, Caldera service running)
- [ ] Verify Caldera scripts role deploys automation tools
- [ ] Verify Windows endpoint: Elastic Agent enrolled, Wazuh agent active, Sysmon installed, Caldera agent connected
- [ ] Verify Ubuntu endpoint: Elastic Agent enrolled, Wazuh agent active, auditd rules applied

### 1.3 Upgrade Path Testing

Test LME 2.2.0 -> 3.0.0 upgrade (AI stack deployment):

- [ ] Start from a clean LME 2.2.0 install (5 containers running)
- [ ] Run `ansible-playbook ansible/pre_upgrade_checks.yml` — all checks pass
- [ ] Run `ansible-playbook ansible/upgrade_lme.yml -e skip_prompts=true`
- [ ] Verify upgrade creates AI directories (`/opt/lme/llama-models`, `/opt/lme/lme-dashboard`)
- [ ] Verify GGUF models download: `LFM2.5-1.2B-Instruct-Q4_K_M.gguf` (~698MB), `nomic-embed-text-v1.5.Q4_K_M.gguf` (~81MB)
- [ ] Verify new secrets created: `pgvector`, `llm-keys`
- [ ] Verify new TLS certs generated for: `llama-cpp`, `embeddings`, `litellm`, `dashboard`, `log-analyzer`
- [ ] Verify all 11 containers running post-upgrade (was 5 core + 6 AI)
- [ ] Verify existing data and indices survived upgrade (no data loss)

### 1.4 Service Health Checks

All containers must pass their built-in health checks:

- [ ] `lme-elasticsearch` — responds on :9200 with auth challenge
- [ ] `lme-kibana` — HTTP 302 on :5601
- [ ] `lme-fleet-server` — `{"status":"HEALTHY"}` on :8220
- [ ] `lme-wazuh-manager` — HTTP 401 on :55000
- [ ] `lme-elastalert` — running (no exposed health endpoint)
- [ ] `lme-llama-cpp` — `/health` returns OK on :8080
- [ ] `lme-embeddings` — `/health` returns OK on :8081
- [ ] `lme-litellm` — responds on :4000
- [ ] `lme-pgvector` — `pg_isready -U lme -d lme_vectors` exits 0
- [ ] `lme-dashboard` — responds on :8502 (HTTPS)
- [ ] `lme-log-analyzer` — responds on :8501 (HTTPS)

### 1.5 Functional Tests

- [ ] Run existing API test suite: `pytest testing/tests/api_tests/linux_only/`
- [ ] Run existing Selenium test suite: `pytest testing/tests/selenium_tests/linux_only/`
- [ ] Verify Kibana dashboards load (Security, Sysmon Summary, User Security)
- [ ] Verify LME Dashboard (:8502) — login, query Elasticsearch, AI-assisted analysis
- [ ] Verify Log Analyzer (:8501) — Streamlit UI loads, can query logs
- [ ] Verify LiteLLM proxy (:4000) — `POST /chat/completions` returns a response using local model
- [ ] Verify embeddings endpoint (:8081) — `POST /embedding` returns vector
- [ ] Verify pgvector stores and retrieves document embeddings
- [ ] Verify Caldera UI (:8888) — accessible, agents check in
- [ ] Verify agent reporting: `testing/v2/installers/lib/check_agent_reporting.sh`

### 1.6 Ludus Role Integration Tests

- [ ] Test `ludus_lme_server` idempotency — re-run doesn't break
- [ ] Test `ludus_lme_agents` selective install — `tasks_from: elastic` only
- [ ] Test `ludus_lme_agents` selective install — `tasks_from: wazuh` only
- [ ] Test fact delegation — `elastic_password` and `lme_ip` accessible on localhost from agent hosts
- [ ] Test Caldera fact delegation — `caldera_ip` and API keys flow to `ludus_caldera_agent`
- [ ] Verify all roles pass with `--check` (dry-run) mode

### 1.7 Validation Script

A `scripts/validate_deployment.sh` script will be produced that:
- Checks all container statuses via `podman ps --format`
- Runs health checks against each service endpoint
- Verifies TLS certificates are valid and not expired
- Checks Elasticsearch cluster health (green/yellow)
- Verifies agent enrollment count in Fleet
- Checks Wazuh agent registration
- Reports pgvector connection and table existence
- Tests LLM inference (simple prompt → response)
- Tests embedding generation
- Outputs a summary table with PASS/FAIL per service
- Documents frontend URLs and login credentials

---

## 2. Security Review

Per the [LME Security Model](https://github.com/cisagov/lme-docs/blob/main/content/docs/markdown/reference/security-model.md), verify all new containers comply with the four-pillar security architecture.

### 2.1 User Isolation (Principle of Least Privilege)

- [ ] **Container users** — Verify each new container runs as a non-root user inside its namespace:
  - `lme-llama-cpp`: runs as non-root (llama.cpp server)
  - `lme-embeddings`: runs as non-root (same image as llama-cpp)
  - `lme-litellm`: runs as non-root
  - `lme-pgvector`: runs as `postgres` user (standard)
  - `lme-dashboard`: runs as non-root (uvicorn)
  - `lme-log-analyzer`: runs as non-root (streamlit)
- [ ] **No container has host-level sudo or root access**
- [ ] **User namespace isolation** — Podman rootless/user-namespace mode active for all new containers
- [ ] **Service users** — Verify new service accounts follow least-privilege:
  - pgvector `lme` user: only `lme_vectors` database access
  - LiteLLM: no direct Elasticsearch write access (read-only via proxy)
  - Dashboard: uses `elastic` user (review if a read-only user is warranted)
  - Log Analyzer: uses `elastic` user (same review)

### 2.2 Secrets Management

- [ ] **Master password encryption** — Verify new secrets are encrypted with the LME master password (`/etc/lme/pass.sh`)
- [ ] **Secrets use `file` driver** — Confirm `pgvector` and `llm-keys` secrets use Podman `file` type (not `shell`), avoiding interactive prompts
- [ ] **No plaintext credentials in quadlet files** — Audit all `.container` files for hardcoded passwords
- [ ] **Hardcoded API key audit** — `LITELLM_API_KEY=sk-lme-llama-proxy` is in `lme-dashboard.container` and `lme-log-analyzer.container`; determine if this should be a secret instead
- [ ] **Secret rotation** — Verify `change_passwords.yml` covers new secrets (pgvector, llm-keys)
- [ ] **Credential inventory** — Document all new credentials:

| Secret | Used By | Storage Method | Rotation |
|--------|---------|----------------|----------|
| `pgvector` (POSTGRES_PASSWORD) | pgvector, dashboard | Podman secret (file driver) | `change_passwords.yml` |
| `llm-keys` | litellm | Podman secret (file mount) | `change_passwords.yml` |
| `elastic` | dashboard, log-analyzer | Podman secret (env) | Existing rotation |
| `sk-lme-llama-proxy` (LiteLLM API key) | dashboard, log-analyzer | Hardcoded env var | **Review needed** |

### 2.3 Network Isolation

- [ ] **All new containers on `lme` network only** — No `--network=host`
- [ ] **Published ports audit** — Only necessary ports exposed to host:
  - `:8080` — llama-cpp (needed? or internal only)
  - `:8081` — embeddings (needed? or internal only)
  - `:4000` — litellm (needed? or internal only)
  - `:5432` — pgvector (needed? or internal only)
  - `:8502` — dashboard (user-facing, expected)
  - `:8501` — log-analyzer (user-facing, expected)
- [ ] **Determine which ports should be internal-only** — llama-cpp, embeddings, litellm, and pgvector may not need host-level port bindings if only accessed by other containers on the `lme` network
- [ ] **Container-to-container communication** — Verify services use internal DNS names (`lme-litellm`, `lme-pgvector`, etc.) not published host ports
- [ ] **No container can reach the internet** at runtime (models pre-downloaded, no phone-home)
- [ ] **Firewall rules** — Document required inbound ports for external access

### 2.4 TLS/Certificate Compliance

- [ ] **All inter-service communication uses TLS** — Verify every container-to-container connection uses HTTPS with LME CA certs
- [ ] **Certificate chain** — New certs (llama-cpp, embeddings, litellm, dashboard, log-analyzer) signed by existing LME CA from `lme_certs` volume
- [ ] **No `--insecure` or `-k` in production health checks** — Audit: some health checks use `curl -k` / `curl -fsk`; determine if CA cert should be mounted for health checks instead
- [ ] **Certificate permissions** — Private keys readable only by container process user
- [ ] **Certificate expiration** — Verify new certs have reasonable validity period (matches existing LME cert policy)
- [ ] **`SSL_CERT_FILE` / `REQUESTS_CA_BUNDLE`** — Verify litellm's combined CA approach (`cat system-ca + lme-ca > combined`) is secure and doesn't introduce trust of unexpected CAs

### 2.5 Container Hardening

- [ ] **Read-only filesystems where possible** — Identify which containers could use `ReadOnly=true`
- [ ] **No privileged containers** — No `--privileged` flag on any new container
- [ ] **No `SYS_ADMIN` or dangerous capabilities** — Audit `PodmanArgs` for capability grants
- [ ] **Volume mount permissions** — Verify `:ro` (read-only) used where containers don't need write access:
  - `lme_certs:/certs:ro` — correct on all new containers
  - `/opt/lme/llama-models:/models:Z` — llama-cpp has write? Should be `:ro` unless model download happens at runtime
  - Dashboard mounts `/opt/lme/config:rw` — needed for model management; review scope
- [ ] **Image provenance** — All AI images built locally from Containerfiles (no unvetted third-party images pulled at runtime)
- [ ] **No shell access exposed** — No containers expose SSH or remote shell

### 2.6 Quadlet/Systemd Compliance

- [ ] **All new containers registered as `PartOf=lme.service`** — Unified lifecycle management
- [ ] **Dependency ordering correct** — `After=` and `Requires=` chains prevent race conditions:
  - litellm requires llama-cpp
  - dashboard requires elasticsearch, litellm, pgvector, embeddings
  - log-analyzer requires elasticsearch, litellm
- [ ] **Restart policies** — All containers have `Restart=always` with burst limits
- [ ] **No `TimeoutStartSec=infinity`** — All have bounded timeouts (review 5400s on dashboard)
- [ ] **Systemd path watchers** — Model update triggers are secure (no arbitrary code execution via watched paths)

### 2.7 Data Protection

- [ ] **pgvector data volume** — `lme_pgvectordata` is a named volume, not a host bind mount (good)
- [ ] **Model files** — `/opt/lme/llama-models` permissions restrict access to root/admin only
- [ ] **No sensitive data in container logs** — Verify containers don't log credentials, API keys, or PII at INFO level
- [ ] **Dashboard session security** — If dashboard has auth, verify session tokens are secure; if no auth, document the risk

### 2.8 Credential & Auth Documentation

Produce a complete credentials reference covering:

- [ ] All new service accounts and their purposes
- [ ] Where each credential is stored (Podman secret name, env var, file path)
- [ ] How each credential is generated (initial install vs. upgrade)
- [ ] How to rotate each credential
- [ ] Default values and whether they MUST be changed
- [ ] Which credentials are shared between containers (blast radius if compromised)


## 3. Front end testing

### 3.1 Access & Navigation
- [ ] **Open Detection Engineering view**
  - [x] Click “Detection Engineering” top nav switches to detection view
  - [x] Sub-tabs visible: **Rules**, **ElastAlert**, **KEVs**
  - [ ] No console errors on entry
- [ ] **Sub-tab switching**
  - [x] Switch Rules → ElastAlert → KEVs → Rules without UI breaking
  - [ ] Switching while data is loading doesn’t freeze/stick spinners
  - [x] Correct sub-tab stays highlighted

---

### 3.2 Rules Tab — Elastic Prebuilt Rules
- [ ] **Prebuilt status loads**
  - [x] Installed/available/updates counts render
  - [ ] “Up to date” message appears only when available=0 and updates=0
  - [ ] Refreshing the tab re-renders correctly (no stale values)
- [ ] **Import Prebuilt Rules (happy path)**
  - [ ] Clicking “Import Prebuilt” disables the button and shows spinner
  - [ ] Success message includes installed/skipped/failed counts
  - [ ] After import, status refreshes and counts update
  - [ ] Kibana rules table refreshes after import (new rules appear)
- [ ] **Import Prebuilt Rules (error handling)**
  - [ ] Kibana unreachable → UI shows error message and button re-enables
  - [ ] Timeout/500 → UI shows failure message and no crash

---

### 3.3 Rules Tab — Sigma Rules Workflow
- [ ] **Sigma status loads**
  - [ ] No converted rules → “No converted rules found” message shown
  - [ ] Converted rules exist → platform cards show rule_count + modified time
- [ ] **Download & Convert**
  - [x] Clicking “Download & Convert” shows converting spinner and disables action
  - [x] On success: platform outputs appear and total rules count is shown
  - [ ] On failure: error message appears and UI recovers
- [ ] **Upload to Kibana (per-platform converted outputs)**
  - [ ] Upload Windows platform
    - [x] Spinner only on Windows card
    - [x] Success message shows imported count and error count (if any)
    - [x] Kibana rules table refreshes after upload
    - [x] Converted file removed after successful upload (Sigma status updates)
  - [ ] Upload Linux platform (same checks)
  - [x] Upload macOS platform (same checks)
- [ ] **Upload NDJSON file (manual)**
  - [ ] Upload valid `.ndjson` imports successfully and shows confirmation message
  - [ ] Upload non-ndjson is rejected (UI shows error)
  - [ ] Upload empty ndjson rejected (UI shows error)
- [ ] **Upload YAML (convert + upload)**
  - [x] Upload 1 Windows Sigma YAML converts/imports successfully
  - [ ] Upload mixed Windows + non-Windows YAML converts/imports successfully
  - [x] Invalid YAML file produces an error entry and does not crash UI
  - [ ] sigma-cli missing/backend 500 → UI shows “Upload failed” message

---

### 3.4 Rules Tab — Kibana Detection Rules Table
- [ ] **Initial table load**
  - [ ] Table renders rows with: name, description snippet, severity, risk score, enabled status
  - [ ] Total count displayed and matches returned count
  - [ ] Loading indicator appears and disappears correctly
- [ ] **Search**
  - [ ] Search text triggers debounced reload
  - [ ] Clearing search restores unfiltered results
  - [ ] Search resets page to 1
- [ ] **Enabled filter**
  - [ ] Filter = All returns both enabled and disabled
  - [ ] Filter = Enabled returns enabled only
  - [ ] Filter = Disabled returns disabled only
- [ ] **Tag filter**
  - [ ] Filter “OS: Windows” returns only that tag set
  - [ ] Filter “OS: Linux” returns only that tag set
  - [ ] Filter “OS: macOS” returns only that tag set
  - [ ] Filter “Sigma Windows” returns Sigma-tagged Windows rules
  - [ ] Filter “Sigma Linux” returns Sigma-tagged Linux rules
  - [ ] Filter “Sigma macOS” returns Sigma-tagged macOS rules
- [ ] **Sorting**
  - [ ] Sort by Rule Name toggles asc/desc correctly
  - [ ] Sort by Severity toggles asc/desc and order looks correct
  - [ ] Sort by Risk toggles asc/desc and order looks correct
  - [ ] Sort by Status toggles asc/desc (enabled grouping consistent)
- [ ] **Pagination**
  - [ ] Next page loads different results and updates “Showing X–Y of total”
  - [ ] Prev page returns to prior results
  - [ ] Prev disabled on page 1
  - [ ] Next disabled on last page
- [ ] **Single rule enable/disable**
  - [ ] Toggling enabled→disabled updates UI
  - [ ] Toggling disabled→enabled updates UI
  - [ ] If API fails, UI reverts to original state
- [ ] **Row selection**
  - [ ] Selecting a row checkbox adds it to selected set
  - [ ] Unselecting removes it from selected set
  - [ ] Select-all selects all visible rules
  - [ ] Select-all toggles back to clear selection
  - [ ] Selection clears on reload/filter/sort/page change
- [ ] **Bulk enable/disable (selected rows)**
  - [ ] Bulk action bar appears when selection > 0
  - [ ] “Enable Selected” prompts confirmation
  - [ ] “Disable Selected” prompts confirmation
  - [ ] After success: selection clears and table refreshes
  - [ ] If API fails: table remains stable; error surfaced (console/alert)
- [ ] **Bulk by OS/Sigma tags**
  - [ ] “Enable All Windows (Elastic)” prompts confirmation and works
  - [ ] “Disable All Windows (Elastic)” prompts confirmation and works
  - [ ] “Enable All Linux (Elastic)” works
  - [ ] “Disable All Linux (Elastic)” works
  - [ ] “Enable All macOS (Elastic)” works
  - [ ] “Disable All macOS (Elastic)” works
  - [ ] Same checks for Sigma Windows/Linux/macOS tags
  - [ ] Kibana rejection/unreachable produces visible error and no crash

---

### 3.5 ElastAlert Tab — Rule File Management
- [ ] **Empty state**
  - [ ] With no rules present, shows “No rules yet” message
- [ ] **List rules**
  - [ ] Rule entries show: filename, name, type, index (when available)
  - [ ] Refresh button reloads list without duplicating entries
- [ ] **Expand rule to view YAML**
  - [ ] Clicking a rule expands and loads YAML
  - [ ] YAML loads only once (subsequent expand uses cached content)
  - [ ] If YAML fetch fails, an error message appears in YAML panel
- [ ] **Upload rule files**
  - [ ] Upload 1 valid `.yml/.yaml` file succeeds and appears in list
  - [ ] Upload multiple valid files succeeds and all appear in list
  - [ ] Upload invalid extension is rejected with error message
  - [ ] Upload invalid YAML (not a YAML mapping) rejected with error message
  - [ ] Partial success (some valid, some invalid) shows saved + errors counts
- [ ] **Paste YAML modal**
  - [ ] Modal opens and closes correctly (X and Cancel work)
  - [ ] Paste valid YAML mapping with `name:` field, no filename:
    - [ ] Backend derives filename and returns it
    - [ ] Rule appears in list
    - [ ] Modal auto-closes after success delay
  - [ ] Paste valid YAML mapping with explicit filename:
    - [ ] Saved under that filename
  - [ ] Paste invalid YAML shows validation error and modal stays open
- [ ] **Delete rule**
  - [ ] Delete prompts confirmation
  - [ ] Deleted rule disappears from list
  - [ ] If deleted rule was expanded, it collapses cleanly
  - [ ] Cached YAML cleared (re-adding same name doesn’t show stale YAML)
- [ ] **Security / validation**
  - [ ] Path traversal filename attempts (e.g., `../x.yml`) are rejected
  - [ ] Non-yaml filename forced by UI/backend gets rejected or normalized safely
  - [ ] Large YAML content doesn’t crash the UI (may fail gracefully)

---

### 3.6 KEVs Tab — Known Exploited Vulnerabilities
- [ ] **KEV status loads**
  - [ ] “Total KEVs” displays catalog total
  - [ ] “Matched” displays count of matched CVEs in environment
  - [ ] “Overdue” displays overdue matched count
  - [ ] “Last Sync” shows a timestamp or “Never”
- [ ] **Badge logic**
  - [ ] If never pulled: badge shows “Never” (or equivalent)
  - [ ] If pulled < 24h ago: badge shows “Current”
  - [ ] If pulled > 24h ago or invalid timestamp: badge shows “Stale”
- [ ] **Sync Now**
  - [ ] Clicking “Sync Now” shows spinner/disabled state
  - [ ] Success message includes synced total CVEs
  - [ ] After sync: status refreshes and last pull time updates
  - [ ] Failure shows error message and button re-enables
- [ ] **Matched KEVs list**
  - [ ] No matches: green “No known exploited vulnerabilities…” empty state card shows
  - [ ] With matches:
    - [ ] Each entry shows CVE link, vendor/product/name/description
    - [ ] Due date shown correctly
    - [ ] “Overdue” label appears when overdue is true
    - [ ] Ransomware label appears when ransomware is Known
    - [ ] Affected hosts chips show and host_count matches chips count
- [ ] **Sorting**
  - [ ] Overdue entries appear first
  - [ ] Then sorted by due date ascending
- [ ] **Refresh behavior**
  - [ ] Refresh button reloads matched list without duplicating entries
- [ ] **Degraded modes**
  - [ ] ES password missing / ES unreachable: status still returns (or fails gracefully) and UI does not crash
  - [ ] Catalog missing: total=0 and UI shows “Never”/empty safely

---

### 3.7 Cross-cutting UX & Reliability
- [ ] **Spinners / disabled states**
  - [ ] Every long operation disables its initiating button and restores it
  - [ ] No spinner stays stuck after failures
- [ ] **Confirmations**
  - [ ] Bulk enable/disable confirms before action
  - [ ] Bulk-by-tag confirms before action
  - [ ] Delete ElastAlert confirms before action
- [ ] **No console errors**
  - [ ] No uncaught JS errors during normal use
  - [ ] No uncaught JS errors during failed API calls

---

### 3.8 Quick Security sanity checks (UI-facing)
- [ ] **XSS safety**
  - [ ] Rule names/descriptions/tags render as text (no injected HTML execution)
  - [ ] ElastAlert YAML content shown in `<pre>` doesn’t execute scripts
- [ ] **Input validation**
  - [ ] ElastAlert filename sanitization works (no directories)
  - [ ] Sigma upload rejects wrong file type and empty content

---

## Execution Order

1. Approve this plan
2. Execute Section 1 (Testing) — deploy to Ludus, run all checks
3. Produce `scripts/validate_deployment.sh` with login documentation
4. Execute Section 2 (Security Review) — audit each container, document findings
5. Produce findings report with remediation recommendations
6. Apply approved remediations

---

## Frontend Access Documentation (to be included in validation script)

| Service | URL | Auth | Notes |
|---------|-----|------|-------|
| Kibana | `https://<lme-server>:5601` | `elastic` / (master-password-encrypted) | Primary SIEM UI |
| LME Dashboard | `https://<lme-server>:8502` | TBD (review if auth exists) | AI-assisted security analysis |
| Log Analyzer | `https://<lme-server>:8501` | TBD (review if auth exists) | Streamlit log analysis |
| Caldera | `http://<caldera-server>:8888` | `red`/`admin` (from local.yml) | Adversary emulation |
| Fleet | `https://<lme-server>:5601/app/fleet` | Same as Kibana | Agent management |
| Wazuh API | `https://<lme-server>:55000` | `wazuh-wui` / (encrypted) | Wazuh management API |
