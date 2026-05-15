# LME Ludus Testing

Parameterized Jupyter notebook tests for validating LME deployments on Ludus cyber ranges.
Automated parallel test execution via Papermill, PDF report generation, and Ludus API integration.

## First-Time Setup

Before running any tests, install the Ansible roles on your Ludus server:

```bash
# From the LME repo root (or the worktree root)
ludus ansible role add -d ansible/roles/ludus_lme_server --force
ludus ansible role add -d ansible/roles/ludus_lme_agents --force

# If using Caldera attack testing:
ludus ansible role add -d ansible/roles/ludus_caldera_server --force
ludus ansible role add -d ansible/roles/ludus_caldera_agent --force
ludus ansible role add -d ansible/roles/ludus_caldera_scripts --force
```

**Re-run these whenever the roles change** (e.g., after pulling new commits or switching branches).
The roles are installed on the Ludus server — if they're stale, deploys will use old code.

## Architecture

```
params.yml                  ← Single source of truth (you edit this)
     │
     ├── generate-range.sh  → range-config.yml
     │
     ├── deploy-range.sh    → Ludus API: set config + deploy + wait + monitors
     │
     └── run-test.sh        → Ludus API: resolve IPs + papermill + PDF
                                  │
                                  └── notebook discovers at runtime:
                                        • elastic password (SSH)
                                        • deployed commit/branch (git)
                                        • all test assertions
```

**params.yml** defines WHAT you're testing — everything else is generated or discovered:

| Derived from params.yml | How |
|------------------------|-----|
| `range-config.yml` | `generate-range.sh` reads params, applies template |
| VM IPs | `run-test.sh` queries Ludus API by `RANGE_NAME` |
| `ELASTIC_PASS` | Notebook extracts via SSH (`extract_secrets.sh`) |
| Deployed commit/branch | Notebook reads `git log` from `/opt/lme-install/` |
| `OFFLINE_IP` | `run-test.sh` auto-sets for ranges with "offline" in name |

## Prerequisites

Install these on the machine running the tests (the Ludus host or a jumpbox with access to range VMs):

| Tool | Purpose | Install |
|------|---------|---------|
| `sshpass` | SSH with password auth to range VMs | `apt install sshpass` |
| `openssh-client` | SSH client | `apt install openssh-client` |
| `python3` | Test runner, Ludus API parsing | Included in Ubuntu |
| `uv` / `uvx` | Papermill + nbconvert runner (no venv needed) | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| `pandoc` + `xelatex` | Report PDF generation (local) | `apt install pandoc texlive-xetex texlive-fonts-recommended fonts-dejavu` |
| `podman` (optional) | Report PDF via container (preferred) | `apt install podman` |
| `curl` | Ludus API calls, health checks | `apt install curl` |
| `rsync` | Required only when `LME_REPO_URL` is a local path | `apt install rsync` |
| `jq`  | JSON parsing in scripts | `apt install jq` |
| `ludus` | Ludus CLI for range deploy, status, IP resolution | See [Ludus releases](https://gitlab.com/badsectorlabs/ludus/-/releases) |

### Ludus CLI Setup

```bash
# Download (replace version as needed)
curl -sL "https://gitlab.com/api/v4/projects/54052321/packages/generic/ludus/<VERSION>/ludus-client_linux-amd64-<VERSION>" \
  -o /usr/local/bin/ludus && chmod +x /usr/local/bin/ludus

# Configure API key
export LUDUS_API_KEY="<your-api-key>"
# Or set in ~/.ludus/config:
#   [ludus]
#   url = https://<ludus-host>:8080
#   api_key = <your-api-key>

# Verify
ludus range list all
```


### Python Dependencies (auto-managed)

`uvx` handles these automatically — no manual install needed:
- `papermill` — parameterized notebook execution
- `ipykernel` — Python3 Jupyter kernel
- `nbconvert` — notebook → LaTeX/PDF conversion

The test notebook uses only Python stdlib (`subprocess`, `json`, `ssl`, `urllib`, `base64`).
No pip packages are required on the test runner.

## Quick Start

```bash
cd testing/ludus

# 0. Install Ludus roles (once per Ludus server, or after role changes)
ludus ansible role add -d ../../ansible/roles/ludus_lme_server --force
ludus ansible role add -d ../../ansible/roles/ludus_lme_agents --force

# 1. Create a range
mkdir -p ranges/my-test
cat > ranges/my-test/params.yml << 'EOF'
RANGE_NAME: "my-test"
LME_BRANCH: "my-feature-branch"
LME_BRANCH_COMMIT: "abc1234"
LME_VERSION: "2.3.0"
LME_REPO_URL: "https://github.com/cisagov/LME.git"
SSH_USER: "localuser"
SSH_PASS: "password"
NOTES: "Testing my feature"
EOF

# 2. Generate range-config.yml from params
bash scripts/generate-range.sh ranges/my-test

# 3. Deploy range + install monitors
bash scripts/deploy-range.sh ranges/my-test

# 4. Run tests (IPs resolved from Ludus API)
bash scripts/run-test.sh ranges/my-test

# 5. Results
ls ranges/my-test/executed-test.{ipynb,pdf}

# Or do everything at once:
bash scripts/run-all.sh ranges/my-test
```

> **Important:** Step 0 must be run whenever the Ansible roles change. If you update
> `ludus_lme_server` or `ludus_lme_agents`, re-push them with `--force` before deploying.

## Test Scenarios

### Fresh Install

```yaml
RANGE_NAME: "fresh-23"
LME_BRANCH: "develop"
LME_BRANCH_COMMIT: ""
LME_VERSION: "2.3.0"
LME_REPO_URL: "https://github.com/cisagov/LME.git"
SSH_USER: "localuser"
SSH_PASS: "password"
NOTES: "Fresh LME 2.3.0 install"
```

Deploys from `LME_BRANCH`, runs full test suite.

### Upgrade (2.2 → 2.3)

```yaml
RANGE_NAME: "upgrade-22-to-23"
LME_BRANCH: "develop"
LME_BRANCH_COMMIT: ""
LME_VERSION: "2.3.0"
LME_REPO_URL: "https://github.com/cisagov/LME.git"
SSH_USER: "localuser"
SSH_PASS: "password"
NOTES: "Upgrade from 2.2.0 to 2.3.0"
UPGRADE_FROM_BRANCH: "main"
UPGRADE_FROM_COMMIT: ""
UPGRADE_FROM_VERSION: "2.2.0"
```

`generate-range.sh` sets `git_ref: "main"` so Ludus deploys 2.2.0 first.
After deploy, SSH in and upgrade:
```bash
cd /opt/lme-install && git checkout develop && bash install.sh
```
Then `run-test.sh` — the notebook checks `UPGRADE_FROM_VERSION` and runs TS-09 (upgrade path validation).

### Offline (Air-Gapped)

```yaml
RANGE_NAME: "offline-test"
LME_BRANCH: "develop"
LME_BRANCH_COMMIT: ""
LME_VERSION: "2.3.0"
LME_REPO_URL: "https://github.com/cisagov/LME.git"
SSH_USER: "localuser"
SSH_PASS: "password"
NOTES: "Air-gapped install — DNS blocked"
```

`generate-range.sh` detects "offline" in the name → sets `ludus_lme_server_offline: true`.
`run-test.sh` detects "offline" in the name → auto-sets `OFFLINE_IP = LME_IP`.
The notebook runs TS-10 (offline test suite: containers, dashboard, DNS blocked, KEV graceful degradation).

## Directory Structure

```
testing/ludus/
├── README.md                              ← this file
├── Dockerfile.jupyter                     ← Jupyter container (optional, for interactive use)
├── templates/
│   ├── testing-evidence-template.ipynb    ← parameterized notebook (Papermill)
│   └── range-config.yml.tpl              ← Ludus range config template
├── scripts/
│   ├── generate-range.sh    ← params.yml → range-config.yml
│   ├── deploy-range.sh      ← Ludus API: deploy + wait + monitors
│   ├── run-test.sh          ← Ludus CLI: resolve IPs + notebook + PDF
│   ├── run-all.sh           ← full pipeline: generate + deploy + test all ranges
│   ├── compile-report.sh    ← notebook → structured report.md + report.pdf
│   ├── deploy-monitors.sh   ← deploy disk monitor to an LME server
│   ├── lme_disk_monitor.sh  ← in-VM automated disk cleanup (cron, 5 tiers + fstrim)
│   ├── lme-audit-check.sh   ← health check all LME servers via Ludus API
│   ├── ludus-fstrim.sh      ← host-side QCOW2 reclaim via fstrim
│   └── README.md            ← detailed script documentation
└── ranges/
    ├── fresh-23/
    │   ├── params.yml             ← you edit this
    │   ├── range-config.yml       ← generated by generate-range.sh
    │   ├── executed-test.ipynb    ← test output (after run-test.sh)
    │   └── executed-test.pdf      ← test report PDF
    ├── upgrade-22-to-23/
    └── offline-23/
```

## params.yml Reference

| Parameter | Required | Description |
|-----------|:---:|-------------|
| `RANGE_NAME` | Yes | Must match the Ludus range name (used by run-test.sh for IP resolution) |
| `LME_BRANCH` | Yes | Git branch deployed on the server |
| `LME_BRANCH_COMMIT` | No | Specific commit SHA to deploy (blank = HEAD of branch) |
| `LME_VERSION` | Yes | Expected LME version (e.g., `2.3.0`) |
| `LME_REPO_URL` | No | Git repo URL or local path (default: `https://github.com/cisagov/LME.git`) |
| `SSH_USER` | Yes | SSH username for all VMs |
| `SSH_PASS` | Yes | SSH password |
| `NOTES` | No | Freeform notes about this test |
| `UPGRADE_FROM_BRANCH` | No | Pre-upgrade branch — triggers upgrade range generation and TS-09 |
| `UPGRADE_FROM_VERSION` | No | Pre-upgrade version (e.g., `2.2.0`) |
| `UPGRADE_FROM_COMMIT` | No | Pre-upgrade commit SHA |

### Testing a Local Repo or Fork

Set `LME_REPO_URL` to a local path (accessible from the Ludus VM) or a fork URL:

```yaml
# Local path (must be accessible from the VM via git clone)
LME_REPO_URL: "/home/mreeve/vibe-home/LME"
LME_BRANCH: "snl-ludus-test-framework"
LME_BRANCH_COMMIT: "414e282"

# Or a fork
LME_REPO_URL: "https://github.com/yourfork/LME.git"
LME_BRANCH: "my-feature"
```

`generate-range.sh` passes this to `ludus_lme_server_repo_url` and uses the commit as `git_ref` if specified (otherwise uses the branch name).

## Scripts Reference

| Script | Input | Output | Purpose |
|--------|-------|--------|---------|
| `generate-range.sh <dir>` | `params.yml` + `range-config.yml.tpl` | `range-config.yml` | Generate Ludus range config from params |
| `deploy-range.sh <dir>` | `range-config.yml` + `params.yml` | Deployed range + monitors | Deploy via Ludus API, wait, install monitors |
| `run-test.sh <dir>` | `params.yml` + Ludus API | `executed-test.ipynb` + `.pdf` | Resolve IPs, run notebook, generate PDF |
| `run-all.sh [dir]` | All `ranges/*/params.yml` | All notebooks + PDFs | Full pipeline: generate + deploy + test |
| `compile-report.sh <dir>` | `executed-test.ipynb` | `report.md` + `report.pdf` | Structured report from notebook |
| `deploy-monitors.sh <ip>` | `lme_disk_monitor.sh` | Cron installed on server | Deploy disk monitor to prevent QCOW2 bloat |
| `lme-audit-check.sh` | Ludus API | Health report | Check all LME servers across all ranges |

## Test Cases (TS-01 through TS-12 + Security)

| Test | What It Validates | Guard |
|------|-------------------|-------|
| TS-01 | 11+ containers running | — |
| TS-02 | ES healthy, Kibana available, Wazuh running, Dashboard, pgvector, Log Analyzer | — |
| TS-03 | Fleet + Wazuh agent enrollment | — |
| TS-04 | 2000+ Sigma detection rules, alerts generated, logs ingested | — |
| TS-05 | 1000+ KEVs in catalog, matched CVEs retrieved | — |
| TS-06 | ElastAlert rules on disk, SMTP config, error count = 0 | — |
| TS-07 | LLM/LiteLLM health, RAG chunk count, active model info | — |
| TS-08 | 6+ Podman secrets, TLS certs valid for AI services | — |
| TS-09 | Upgrade path: post-upgrade containers + ES version | `UPGRADE_FROM_VERSION` |
| TS-10 | Offline: containers, dashboard, DNS blocked, KEV graceful fail | `OFFLINE_IP` |
| TS-11 | Caldera service active, agents enrolled | `CALDERA_IP` |
| TS-12 | 10 RAG chat prompts return >20 chars each | — |
| TS-VULN | Wazuh vulnerability detection (install Firefox ESR, wait, verify) | `UBUNTU_IP` |
| Security | Unauth access check, static API keys, container privileges, port exposure, TLS audit | — |

Guarded tests print `SKIP` when their guard parameter is empty.

## Ludus Roles

The Ansible roles handle credential flow automatically — no hardcoded passwords in range configs:

- **`ludus_lme_server`** — clones LME from `ludus_lme_server_git_ref`, runs `install.sh`, extracts secrets, exports `elastic_password` and `lme_ip` as localhost facts
- **`ludus_lme_agents`** — auto-resolves `server_ip` and `elastic_password` from localhost facts via `depends_on`. Falls back to explicit `role_vars` if facts aren't available.

See `ansible/ranges/lme-minimal.yml` for the simplest example (single server, self-monitoring, zero credentials in config).

## Resource Requirements

Each range needs these VMs on Proxmox:

| VM | RAM | CPUs | Disk |
|----|-----|------|------|
| LME Server | 32 GB | 4 | ~120 GB (with AI stack) |
| Windows 11 Endpoint | 8 GB | 2 | ~15 GB |
| Ubuntu Endpoint | 4-8 GB | 2 | ~12 GB |
| Router (auto) | 2 GB | 2 | ~5 GB |

**Per range total:** ~46-54 GB RAM, 10 CPUs, ~152 GB disk

Deploy disk monitors (`deploy-monitors.sh`) to every LME server before testing to prevent Wazuh vulnerability feed data from filling the Proxmox host disk.

## Conventions

- One directory per range under `ranges/`
- `params.yml` is the only hand-edited file per range
- `range-config.yml` is always generated — never edit by hand
- `executed-test.ipynb` and `.pdf` are test artifacts (gitignored)
- Deploy `lme_disk_monitor.sh` to every LME server before testing
- Run `lme-audit-check.sh` before and after test runs for health checks
- Tag notebooks with date if re-running: `executed-test-YYYY-MM-DD.ipynb`
