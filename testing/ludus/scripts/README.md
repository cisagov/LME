# Ludus Testing Scripts

Scripts for managing LME test ranges on Ludus cyber ranges.

## Test Execution

### `run-test.sh <range-dir>`

Execute the parameterized test notebook for a single range.

- Reads `params.yml` from the range directory
- Runs Papermill to inject parameters and execute all cells
- Converts the executed notebook to PDF via nbconvert + xelatex
- **Requires:** `uvx` (with papermill + ipykernel), `xelatex`
- **Output:** `<range-dir>/executed-test.ipynb` + `executed-test.pdf`

```bash
bash scripts/run-test.sh ranges/fresh-23-install
```

### `run-all-tests.sh`

Execute tests for ALL ranges in `ranges/` **in parallel**.

- Finds every subdirectory with a `params.yml`
- Launches `run-test.sh` for each as a background job
- Waits for all to complete, reports pass/fail
- **Output:** per-range `test-run.log` for debugging failures

```bash
bash scripts/run-all-tests.sh
```

### `compile-report.sh <range-dir>`

Convert an executed test notebook into a structured report.

- Extracts markdown + code + output from the notebook into `report.md`
- Compiles to PDF using **podman pandoc container** (preferred) or **local pandoc** (fallback)
- **Requires:** `podman` OR `pandoc` + `xelatex`
- **Output:** `<range-dir>/report.md` + `report.pdf`

```bash
bash scripts/compile-report.sh ranges/fresh-23-install
```

## Infrastructure Management

### `deploy-monitors.sh <lme-server-ip> [user] [password]`

Deploy the disk monitor script to an LME server and install the cron job.

- SCPs `lme_disk_monitor.sh` to the target
- Installs a cron job that runs every minute
- Idempotent — safe to run multiple times
- **Run this on every LME server before testing**

```bash
bash scripts/deploy-monitors.sh 10.1.10.10
bash scripts/deploy-monitors.sh 10.1.10.10 localuser password
```

### `lme_disk_monitor.sh`

Automated disk cleanup that runs via cron every minute on each LME server. Performs tiered cleanup when guest disk exceeds 60%, and **always runs fstrim** regardless of threshold to reclaim QCOW2 space on the Proxmox host.

| Tier | Trigger | Action | Forensic Impact |
|------|---------|--------|:---:|
| fstrim | **Always** (every run) | `fstrim -av` — tells hypervisor which blocks are free | None |
| 1 | Wazuh vd_updater/tmp > 1GB or feed > 5GB | Clear Wazuh vulnerability cache (auto-redownloads) | None |
| 2a | `.ds-metrics-*` / `.ds-logs-*` > 1 day old | Delete old ES metrics/logs indices | Loses old metrics |
| 2b | `wazuh-alerts-*` > 3 days (or > 500MB after 1 day) | Delete old Wazuh alert indices | Loses old alerts |
| 2c | Security alerts index > 500MB | Delete oldest 50% older than 1 day | Loses old alerts |
| 3 | Unused container images | `podman image prune -af` | None |
| 4 | System | `apt clean` + `journalctl --vacuum-size=100M` | Loses old logs |

### `ludus-fstrim.sh`

**Runs on the Ludus host (not inside VMs).** Discovers all powered-on VMs via the Ludus API and runs `fstrim` on each via SSH in parallel.

This is the primary defense against Proxmox host disk exhaustion. Guest VMs can show 20% disk usage while their QCOW2 images balloon to 100GB+ because the hypervisor doesn't know which blocks are free until `fstrim` tells it.

- **Safe for forensics** — fstrim only marks freed blocks as reusable at the storage layer, does not modify file contents
- Discovers VMs automatically via Ludus API (no hardcoded IPs)
- Runs SSH in parallel for speed
- Self-installing cron support

```bash
# Run once
bash scripts/ludus-fstrim.sh

# Install as cron (every 5 minutes)
bash scripts/ludus-fstrim.sh --install

# Remove cron
bash scripts/ludus-fstrim.sh --uninstall

# Check logs
tail -f /var/log/ludus-fstrim.log
```

**Requires:** `sshpass`, `curl`, `python3`, Ludus API credentials (`~/.ludus/config`)

### `lme-audit-check.sh`

Polls all LME servers discovered from the Ludus API and verifies:

- SSH connectivity (with diagnostic hints on failure)
- Disk monitor cron installed
- Disk monitor script exists
- Last monitor log entry
- Current disk usage (color-coded: green < 40%, yellow < 60%, red >= 60%)
- Container count (color-coded: green >= 11, yellow >= 5, red < 5)

```bash
# Uses ~/.ludus/config automatically
bash scripts/lme-audit-check.sh

# Or pass credentials explicitly
LUDUS_URL=https://host:8080 LUDUS_API_KEY=key bash scripts/lme-audit-check.sh
```

On SSH failure, prints diagnostics:
- Connection refused → sshd not running
- Timeout → VM powered off or IP unreachable
- Permission denied → wrong credentials
- Host key mismatch → stale known_hosts (script ignores this automatically)
