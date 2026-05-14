# LME Ludus Testing Methodology

Testing framework for validating LME deployments on Ludus cyber ranges using parameterized Jupyter notebooks, automated parallel test execution via Papermill, and PDF report generation.

## Prerequisites

Install these on the machine running the tests:

| Tool | Purpose | Install |
|------|---------|---------|
| `sshpass` | SSH with password auth | `apt install sshpass` |
| `openssh-client` | SSH client | `apt install openssh-client` |
| `python3` | Test runner | Included in Ubuntu |
| `uv` / `uvx` | Papermill + nbconvert runner | Download installer from https://astral.sh/uv/install.sh, inspect, then execute |
| `pandoc` + `xelatex` | Report PDF generation (local) | `apt install pandoc texlive-xetex texlive-fonts-recommended fonts-dejavu` |
| `podman` (optional) | Report PDF via container (preferred) | `apt install podman` |
| `curl` | API calls | `apt install curl` |
| `ludus` (optional) | Ludus CLI for range management | Download from [Ludus releases](https://gitlab.com/badsectorlabs/ludus/-/releases) — extract binary to `/usr/local/bin/ludus` |

If `ludus` CLI is not installed, you can manage ranges via the REST API directly:
```bash
LUDUS_URL="https://<host>:8080"
LUDUS_KEY="<your-api-key>"
# List ranges
curl -sk "$LUDUS_URL/api/v2/range/all" -H "X-API-KEY: $LUDUS_KEY"
# Deploy
curl -sk -X POST "$LUDUS_URL/api/v2/range/deploy?rangeID=<id>" \
  -H "X-API-KEY: $LUDUS_KEY" -d '{}'
```

API key and URL are stored in `~/.ludus/config`.

## Directory Structure

```
testing/ludus/
├── README.md                    <- this file
├── Dockerfile.jupyter           <- Jupyter container with all test deps
├── templates/
│   ├── testing-evidence-template.ipynb  <- parameterized notebook (Papermill)
│   └── CREDENTIALS.md.template          <- credentials template (all VMs)
├── scripts/
│   ├── run-test.sh              <- execute tests for one range
│   ├── run-all-tests.sh         <- execute tests for all ranges (PARALLEL)
│   ├── compile-report.sh        <- notebook -> report.md + report.pdf (podman or local pandoc)
│   ├── deploy-monitors.sh       <- deploy disk monitor to an LME server
│   ├── lme_disk_monitor.sh      <- automated disk cleanup (cron, 5 tiers)
│   └── lme-audit-check.sh       <- audit all LME servers via Ludus API
└── ranges/
    ├── fresh-23-install/        <- one directory per range
    ├── upgrade-22-to-23/
    ├── offline-test/
    └── attack-test/             <- K8s adversary simulation (see ranges/attack-test/README.md)
```

## Deliverables Per Range

Each range directory produces these artifacts:

```
ranges/<range-id>/
├── params.yml              - test parameters (branch, commit, IPs)
├── range-config.yml        - Ludus range config (reproducible)
├── CREDENTIALS.md          - access creds for ALL VMs (gitignored)
├── executed-test.ipynb     - test notebook with output
├── executed-test.pdf       - notebook compiled as PDF
├── report.md               - structured report source
└── report.pdf              - final compiled report
```

## Quick Start

### 1. Start Jupyter (once)

Build and run the Jupyter container. This only needs to be done **once** -- it persists across test runs. Do not restart between tests.

```bash
# Build
podman build -t jupyter-lme-test -f Dockerfile.jupyter .

# Run (mount entire LME repo)
podman run -d --name jupyter \
  -p 8888:8888 \
  -v /path/to/LME:/home/jovyan/LME \
  --user root -e GRANT_SUDO=yes \
  jupyter-lme-test

# Access at http://<host>:8888/lab?token=lme
```

### 2. Create a Range

```bash
mkdir -p ranges/my-test
cp ranges/fresh-23-install/params.yml ranges/my-test/params.yml
# Edit params.yml: set IPs, branch, commit, notes
```

### 3. Deploy Monitors (per LME server)

**Every LME server must have the disk monitor before testing.** This prevents Wazuh vulnerability feed data from filling the Proxmox host disk.

```bash
bash scripts/deploy-monitors.sh <LME_SERVER_IP>
```

Verify all servers:
```bash
LUDUS_URL=https://<host>:8080 LUDUS_API_KEY=<key> bash scripts/lme-audit-check.sh
```

### 4. Run Tests

```bash
# Single range
bash scripts/run-test.sh ranges/fresh-23-install

# All ranges (parallel)
bash scripts/run-all-tests.sh
```

### 5. Generate Reports

```bash
bash scripts/compile-report.sh ranges/fresh-23-install
# -> ranges/fresh-23-install/report.md + report.pdf
```

## Parameters (params.yml)

| Parameter | Required | Description |
|-----------|:---:|-------------|
| `RANGE_NAME` | Yes | Human-readable name |
| `LME_IP` | Yes | LME server IP |
| `CALDERA_IP` | No | Caldera server IP (blank = skip Caldera tests) |
| `OFFLINE_IP` | No | LME IP for offline tests (blank = skip) |
| `LME_BRANCH` | Yes | Git branch deployed (e.g., `develop`, `main`) |
| `LME_BRANCH_COMMIT` | Yes | Git commit SHA being tested |
| `LME_VERSION` | Yes | Expected LME version (e.g., `2.3.0`) |
| `SSH_USER` | Yes | SSH username for all VMs |
| `SSH_PASS` | Yes | SSH password |
| `ELASTIC_PASS` | No | Elastic password (blank = auto-extract) |
| `NOTES` | No | Freeform notes about this run |

For upgrade tests, add:

| Parameter | Description |
|-----------|-------------|
| `UPGRADE_FROM_BRANCH` | Original branch before upgrade (e.g., `main`) |
| `UPGRADE_FROM_COMMIT` | Original commit SHA before upgrade |
| `UPGRADE_FROM_VERSION` | Original version (e.g., `2.2.0`) |

## Scripts

See **[`scripts/README.md`](scripts/README.md)** for detailed documentation of each script:

- `run-test.sh` / `run-all-tests.sh` — Execute parameterized test notebooks
- `compile-report.sh` — Convert notebooks to report.md + report.pdf
- `deploy-monitors.sh` — Deploy disk monitor to LME servers
- `lme_disk_monitor.sh` — In-VM disk cleanup (cron, 5 tiers + fstrim)
- `ludus-fstrim.sh` — **Host-side** QCOW2 reclaim via fstrim on all VMs (install on Ludus host)
- `lme-audit-check.sh` — Health check all LME servers via Ludus API

## Test Cases (TS-01 through TS-12)

| Test | What It Validates |
|------|-------------------|
| TS-01 | 11 containers running |
| TS-02 | All services healthy (authenticated) |
| TS-03 | Fleet + Wazuh agent enrollment |
| TS-04 | Sigma rules (2,415+ in Kibana) |
| TS-05 | CISA KEV integration (1,583+ CVEs) |
| TS-06 | ElastAlert email notifications (Gmail) |
| TS-07 | AI/LLM stack (inference, embeddings, RAG) |
| TS-08 | TLS certificates + Podman secrets |
| TS-09 | Upgrade path (2.2 -> 2.3) |
| TS-10 | Offline install (DNS blocked) |
| TS-11 | Caldera integration |
| TS-12 | AI Chat (10 RAG prompts) |
| Security | Privilege audit, port audit, TLS audit |

## Attack Testing

For adversary simulation and forensic evidence collection, see:

**[`ranges/attack-test/README.md`](ranges/attack-test/README.md)**

Covers K3s + Kubernetes Goat deployment, Caldera adversary profiles, MITRE ATT&CK chain execution, and forensic evidence collection methodology.

## Report Pipeline

```
params.yml + template.ipynb
         |
         v
    +----------+
    | papermill |   scripts/run-test.sh
    +----+-----+
         |
         v
  executed-test.ipynb (notebook with outputs)
         |
         +---> nbconvert -> LaTeX -> xelatex -> executed-test.pdf
         |
         +---> scripts/compile-report.sh
              |
              +---> report.md (structured markdown)
              |
              +---> podman pandoc/extra -> report.pdf
                   (or local pandoc fallback)
```

## Resource Requirements

Each range needs these VMs on Proxmox:

| VM | RAM | CPUs | Disk |
|----|-----|------|------|
| LME Server | 32 GB | 4 | ~120 GB (with AI stack) |
| Caldera Server | 8 GB | 2 | ~15 GB |
| Windows 11 Endpoint | 8 GB | 2 | ~15 GB |
| Ubuntu Endpoint | 4-8 GB | 2 | ~12 GB |
| Router (auto) | 2 GB | 2 | ~5 GB |

**Per range total:** ~54 GB RAM, 10 CPUs, ~167 GB disk

**4 ranges simultaneously:** ~216 GB RAM, 40 CPUs, ~668 GB disk

> **Note:** The `attack-test` range omits the Win11 endpoint, reducing to ~46 GB RAM. Total for all 4 ranges is closer to ~200 GB RAM. Ensure the Proxmox host has sufficient resources. Deploy disk monitors on every LME server to prevent QCOW2 disk images from exhausting host storage.

## Conventions

- One directory per range under `ranges/`
- `params.yml` records the **branch + commit** being tested
- For upgrade tests, record both the original and upgrade branch/commit
- `CREDENTIALS.md` includes ALL VMs in the range (gitignored -- never commit)
- Deploy `lme_disk_monitor.sh` to **every** LME server before testing
- Run `lme-audit-check.sh` before and after test runs
- Tag notebooks with date if re-running: `executed-test-YYYY-MM-DD.ipynb`
- Jupyter only needs to be started once -- it persists across test runs
