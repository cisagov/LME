# Agent Prompt: Full LME Cluster Setup and Password Change Test

Use this prompt with a fresh agent to set up an LME cluster on Azure and run the password change test.

---

## Prompt (copy and paste)

```
Set up an LME cluster on Azure and run the password change test. Follow these steps:

1. **Delete any existing cluster first** (to avoid resource constraints):
   - Run: `az group delete --name LME-cbaxley-cl2 --yes --no-wait` (if it exists)
   - Run: `az group delete --name LME-cbaxley-cl1 --yes --no-wait` (if it exists)
   - Wait for deletion to complete: poll `az group exists -n LME-cbaxley-cl1` until it returns false (sleep 20 seconds between checks, up to ~10 minutes)

2. **Verify exporter.txt** in `testing/v2/installers/exporter.txt` has:
   - `RESOURCE_GROUP="LME-cbaxley-cl1"`
   - Other required vars: PUBLIC_IP, LME_USER, BRANCH, etc.

3. **Run setup_cluster.sh**:
   - `cd testing/v2/installers/cluster_installer && ./setup_cluster.sh`
   - **Important**: The install takes ~60-70 minutes. Do NOT let it timeout. Run it and poll the terminal output periodically (e.g. sleep 10-15 minutes between checks). Wait until you see "Cluster setup complete" and exit code 0.

4. **Verify cluster health and shards** (optional but recommended):
   - Get MASTER_IP from `output/LME-cbaxley-cl1.machines.json` (jq -r '.linux_vms[0].ip_address')
   - Run: `ssh lme-user@<MASTER_IP> 'sudo bash -c "source /opt/lme/scripts/extract_secrets.sh -q && curl -sk -u \"elastic:\$elastic\" https://localhost:9200/_cluster/health?pretty"'`
   - Run: `ssh lme-user@<MASTER_IP> 'sudo bash -c "source /opt/lme/scripts/extract_secrets.sh -q && curl -sk -u \"elastic:\$elastic\" https://localhost:9200/_cat/shards?v"'`
   - Confirm status is green and shards are distributed across all 3 nodes.

5. **Run the password change test**:
   - `cd testing/v2/installers/cluster_installer && ./test_change_passwords.sh`
   - All 8 tests should pass.

6. **Clean up when done**:
   - `az group delete --name LME-cbaxley-cl1 --yes --no-wait`
```

---

## Files to check

- `testing/v2/installers/exporter.txt` - Must have RESOURCE_GROUP, PUBLIC_IP, LME_USER, BRANCH
- `testing/v2/installers/cluster_installer/output/` - After setup: `LME-cbaxley-cl1.password.txt`, `LME-cbaxley-cl1.machines.json`

## Prerequisites

- Azure CLI authenticated (`az login`)
- SSH key at `~/.ssh/id_rsa`
- `jq` and `sshpass` installed
