# Ludus Testing Scripts

Scripts for managing LME test ranges on Ludus cyber ranges.

## Pipeline Scripts

These run in order: generate → deploy → test.

### `generate-range.sh <range-dir>`

Generate `range-config.yml` from `params.yml` and `templates/range-config.yml.tpl`.

- Reads `RANGE_NAME`, `LME_BRANCH`, `LME_BRANCH_COMMIT`, `LME_VERSION`, `LME_REPO_URL` from params.yml
- If `UPGRADE_FROM_BRANCH` is set: deploys from that branch (upgrade ranges)
- If range name contains "offline": sets `ludus_lme_server_offline: true`
- If `LME_BRANCH_COMMIT` is set: uses commit SHA as `git_ref` instead of branch name
- If `LME_REPO_URL` is a local directory: range-config uses GitHub URL (VMs can't reach host), `deploy-range.sh` handles the rsync
- **Requires:** `lib-params.sh`

```bash
bash scripts/generate-range.sh ranges/fresh-23
```

### `deploy-range.sh <range-dir>`

Deploy a range via Ludus CLI, sync code, install monitors, run upgrades.

Flow:
1. Set range config via `ludus range config set`
2. Deploy via `ludus range deploy`
3. Poll `ludus range status` until SUCCESS or FAILED
4. Resolve LME server IP via `ludus range list`
5. If `LME_REPO_URL` is a local path (non-upgrade): rsync to server + re-run `install.sh`
6. Deploy disk monitors
7. If `UPGRADE_FROM_BRANCH` is set: rsync target branch to server + run `install.sh` (upgrade)

- **Requires:** `ludus` CLI, `sshpass`, `rsync` (only if `LME_REPO_URL` is a local path)

```bash
bash scripts/deploy-range.sh ranges/fresh-23
```

### `run-test.sh <range-dir>`

Resolve IPs from Ludus, run the test notebook, generate PDF.

Flow:
1. Validate params.yml (all required fields present)
2. Resolve VM IPs via `ludus -r <RANGE_NAME> range list`
3. Auto-set `OFFLINE_IP = LME_IP` for offline ranges
4. Run papermill with params.yml + resolved IPs as extra `-p` flags
5. Convert notebook to PDF via nbconvert + xelatex

- **Requires:** `ludus` CLI, `uvx` (with papermill + ipykernel), `sshpass`, `xelatex`
- **Output:** `<range-dir>/executed-test.ipynb` + `executed-test.pdf`

```bash
bash scripts/run-test.sh ranges/fresh-23
```

### `run-all.sh [range-dir]`

Full pipeline: generate → deploy → test for all ranges (or a single range).

- Phase 1: `generate-range.sh` for each range
- Phase 2: `deploy-range.sh` for each range (sequential — Ludus deploys one at a time)
- Phase 3: `run-test.sh` for all ranges (parallel)
- **Output:** per-range `executed-test.ipynb`, `executed-test.pdf`, `test-run.log`

```bash
bash scripts/run-all.sh                    # all ranges
bash scripts/run-all.sh ranges/fresh-23    # single range
```

### `lib-params.sh`

Shared library sourced by all pipeline scripts. Provides:
- `read_param <key> [default]` — read a value from `$PARAMS_FILE`
- `validate_params` — check all required fields are set, exit on failure

Required fields: `RANGE_NAME`, `LME_BRANCH`, `LME_BRANCH_COMMIT`, `LME_VERSION`, `SSH_USER`, `SSH_PASS`

## Report Generation

### `compile-report.sh <range-dir>`

Convert an executed test notebook into a structured report.

- Extracts markdown + code + output from the notebook into `report.md`
- Compiles to PDF using **podman pandoc container** (preferred) or **local pandoc** (fallback)
- **Requires:** `podman` OR `pandoc` + `xelatex`
- **Output:** `<range-dir>/report.md` + `report.pdf`

```bash
bash scripts/compile-report.sh ranges/fresh-23
```

## Infrastructure Management

### `deploy-monitors.sh <lme-server-ip> [user] [password]`

Deploy the disk monitor script to an LME server and install the cron job.

- SCPs `lme_disk_monitor.sh` to the target
- Installs a cron job that runs every minute
- Idempotent — safe to run multiple times
- Called automatically by `deploy-range.sh`

```bash
bash scripts/deploy-monitors.sh 10.1.10.10
bash scripts/deploy-monitors.sh 10.1.10.10 localuser password
```

### `lme_disk_monitor.sh`

Automated disk cleanup that runs via cron every minute on each LME server. Performs tiered cleanup when guest disk exceeds 60%, and **always runs fstrim** regardless of threshold to reclaim QCOW2 space on the Proxmox host.

| Tier | Trigger | Action | Forensic Impact |
|------|---------|--------|:---:|
| fstrim | **Always** (every run) | `fstrim -av` — tells hypervisor which blocks are free | None |
| 1 | Wazuh vd_updater/tmp > 1GB or feed > 5GB | Clear Wazuh vulnerability cache | None |
| 2a | `.ds-metrics-*` / `.ds-logs-*` > 1 day old | Delete old ES metrics/logs indices | Loses old metrics |
| 2b | `wazuh-alerts-*` > 3 days (or > 500MB after 1 day) | Delete old Wazuh alert indices | Loses old alerts |
| 2c | Security alerts index > 500MB | Delete oldest 50% older than 1 day | Loses old alerts |
| 3 | Unused container images | `podman image prune -af` | None |
| 4 | System | `apt clean` + `journalctl --vacuum-size=100M` | Loses old logs |

### `ludus-fstrim.sh`

**Runs on the Ludus host (not inside VMs).** Discovers all powered-on VMs via the Ludus API and runs `fstrim` on each via SSH in parallel.

- Primary defense against Proxmox host disk exhaustion
- Guest VMs can show 20% usage while QCOW2 images balloon to 100GB+
- Safe for forensics — only marks freed blocks as reusable
- Self-installing cron support

```bash
bash scripts/ludus-fstrim.sh              # Run once
bash scripts/ludus-fstrim.sh --install    # Install cron (every 5 min)
bash scripts/ludus-fstrim.sh --uninstall  # Remove cron
```

### `lme-audit-check.sh`

Health check all LME servers discovered from the Ludus API.

- SSH connectivity (with diagnostic hints on failure)
- Disk monitor cron + script installed
- Current disk usage (color-coded: green < 40%, yellow < 60%, red >= 60%)
- Container count (color-coded: green >= 11, yellow >= 5, red < 5)

```bash
bash scripts/lme-audit-check.sh
```
