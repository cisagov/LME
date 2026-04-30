# LME Backup Operations

This guide covers how to create backups of your LME (Logging Made Easy) installation using Ansible playbooks.

## Overview

The LME backup system creates comprehensive backups of your entire LME installation, including:
- Configuration files and environment settings
- All Podman volumes containing data (Elasticsearch indices, Kibana configurations, Wazuh data, etc.)
- Container image references and versions
- Security certificates and vault data

For clustered deployments, use a two-layer recovery model:
- `ansible/cluster_backup_lme.yml` for the supported cluster backup workflow
- `ansible/backup_lme.yml` for host/master recovery state on an individual node

When `backup_lme.yml` detects a cluster installation, it excludes Elasticsearch
data volumes and records that Elasticsearch snapshots are required for cluster
data recovery.

## ⚠️ Space Requirements

**CRITICAL: Ensure you have sufficient disk space before running any backup operations.**

### Space Calculation
You need **at least 2x the current LME data usage** in free space:
- 1x for the existing data
- 1x for the backup copy

### Check Available Space
```bash
# Get container storage location
STORAGE_ROOT=$(cat /etc/containers/storage.conf | grep graphroot | cut -d'"' -f2 || echo "/var/lib/containers/storage")

# Check space on volumes directory
echo "=== LME Data Storage ==="
df -h "$STORAGE_ROOT/volumes"

# Check backup storage space
BACKUP_DIR="$STORAGE_ROOT/backups"
if [ -L "$BACKUP_DIR" ]; then
    BACKUP_TARGET=$(readlink -f "$BACKUP_DIR")
    echo ""
    echo "=== Backup Storage (symlinked) ==="
    df -h "$BACKUP_TARGET"
else
    echo ""
    echo "=== Backup Storage (same as data) ==="
    df -h "$STORAGE_ROOT"
fi

# Show current LME data usage
echo ""
echo "=== Current LME Data Usage ==="
sudo du -sh "$STORAGE_ROOT/volumes/lme_"* 2>/dev/null | head -5 || echo "No LME volumes found"
```

### Default Storage Locations
- **Container Storage**: `/var/lib/containers/storage` (default)
- **Backup Location**: Same directory as container storage + `/backups/`
- **Configuration**: `/opt/lme/`

### Recommended: Symlink Backups to Separate Storage
For better space management, you can symlink the backups directory to a separate volume. This allows you to:
- Store backups on a separate disk/volume
- Avoid filling up the main container storage
- Better manage backup retention and cleanup

#### Step 1: Identify Your Container Storage Location
First, find where your container storage is located:
```bash
# Check container storage configuration
cat /etc/containers/storage.conf | grep graphroot

# Example output: graphroot = "/var/lib/containers/storage"
```

#### Step 2: Choose Your Backup Storage Location
Decide where you want to store backups. This should be on a separate volume with sufficient space. Common locations:
- `/mnt/backup-storage/` (mounted external drive)
- `/home/backups/` (separate partition)
- `/opt/backups/` (dedicated backup volume)

#### Step 3: Check for Existing Backups
Before making changes, check if you have existing backups that need to be preserved:
```bash
# Replace /var/lib/containers/storage with your actual storage root
STORAGE_ROOT="/var/lib/containers/storage"  # Adjust this path

# Check if backups directory exists and list contents
if [ -d "$STORAGE_ROOT/backups" ]; then
    echo "Existing backups found:"
    sudo ls -la "$STORAGE_ROOT/backups"
    
    # Count backup directories (timestamp format: 20YYMMDDTHHMMSS)
    sudo find "$STORAGE_ROOT/backups" -maxdepth 1 -type d -name "20*" | wc -l
else
    echo "No existing backups directory found"
fi
```

#### Step 4: Stop LME Service
```bash
sudo systemctl stop lme.service
```

#### Step 5: Set Up New Backup Location
Create your backup directory on the separate storage:
```bash
# Example: Using /mnt/backup-storage as the separate volume
sudo mkdir -p /mnt/backup-storage/lme-backups
sudo chown root:root /mnt/backup-storage/lme-backups
sudo chmod 700 /mnt/backup-storage/lme-backups
```

#### Step 6: Move Existing Backups (If Any)
If you found existing backups in Step 3, move them to the new location:
```bash
# Only run this if you have existing backups to preserve
sudo mv "$STORAGE_ROOT/backups"/* /mnt/backup-storage/lme-backups/

# Verify the move was successful
sudo ls -la /mnt/backup-storage/lme-backups/
```

#### Step 7: Remove Old Backups Directory
```bash
# Remove the old backups directory (should be empty after moving backups)
sudo rm -rf "$STORAGE_ROOT/backups"
```

#### Step 8: Create Symlink
```bash
# Create symlink from container storage to your backup location
sudo ln -s /mnt/backup-storage/lme-backups "$STORAGE_ROOT/backups"
```

#### Step 9: Verify Setup
```bash
# Check that symlink was created correctly
ls -la "$STORAGE_ROOT/backups"
# Should show: backups -> /mnt/backup-storage/lme-backups

# Verify you can access the directory
sudo ls -la "$STORAGE_ROOT/backups/"
```

#### Step 10: Restart LME Service
```bash
sudo systemctl start lme.service
```

#### Verification
After setup, verify everything works:
```bash
# Test that backup operations can access the symlinked directory
cd ~/LME/ansible
ansible-playbook backup_lme.yml -e skip_prompts=true

# Check that backup was created in the new location
sudo ls -la /mnt/backup-storage/lme-backups/
```

#### Important Notes
- **Adjust paths**: Replace `/mnt/backup-storage` with your actual backup storage path
- **Permissions**: Ensure the backup storage location has proper permissions (root:root, 700)
- **Mount persistence**: If using external storage, ensure it's properly mounted and will remount on reboot
- **Space monitoring**: Monitor both container storage and backup storage space usage

## Backup Types

### Interactive Backup
Prompts for confirmation and shows progress:
```bash
cd ~/LME/ansible
ansible-playbook backup_lme.yml
```

### Automated Backup
Runs without prompts (useful for scripts/cron):
```bash
cd ~/LME/ansible
ansible-playbook backup_lme.yml -e skip_prompts=true
```

### Cluster Backup Bundle
Use this for multi-node Elasticsearch clusters:
```bash
cd ~/LME
ansible-playbook -i ansible/inventory/cluster.yml ansible/cluster_backup_lme.yml
```

This creates:
- An Elasticsearch snapshot for cluster data
- A master/control-plane backup bundle on the LME master
- A `cluster_recovery_manifest.yml` file linking both artifacts

When shared storage is mounted at `/mnt/es-snapshots`, the workflow also exports
the master recovery bundle to:

```bash
/mnt/es-snapshots/lme-master-backups/<timestamp>
```

## What Gets Backed Up

### 1. LME Installation Directory
- **Location**: `/opt/lme/`
- **Contents**:
  - `lme-environment.env` (configuration)
  - `config/` directory
  - Quadlet files
  - LLM model weights (`llama-models/`), dashboard sources, KEV catalog/history,
    LiteLLM config, and trigger/status files used by the helper services

### 2. LME Vault and Security Files
- **Location**: `/etc/lme/`
- **Contents**:
  - `pass.sh` (master password for vault)
  - `vault/` directory (encrypted password files)
  - `version` file
  - Security certificates and vault data

### 3. Quadlet Files
- **Location**: `/etc/containers/systemd/`
- All `.container`, `.volume`, and `.network` files for the LME stack.

### 4. LME-owned Host Systemd Units
- **Location**: `/etc/systemd/system/`
- An allowlist of LME helper units installed by Ansible roles (LLM and KEV
  helpers plus the umbrella `lme.service`):
  - `lme.service`
  - `lme-llm-keys.service` / `lme-llm-keys.path`
  - `lme-llama-model.service` / `lme-llama-model.path`
  - `lme-kev-sync.service` / `lme-kev-sync.timer`
- Each unit's enabled state is recorded in
  `etc_systemd_system_lme/manifest.txt` so the restore playbooks can
  reapply the `enable`/`disable` state after copying the files back.

### 5. Podman Volumes
All LME-related volumes are backed up:
- `lme_esdata01` - Elasticsearch data
- `lme_kibanadata` - Kibana configurations
- `lme_certs` - SSL/TLS certificates
- `lme_wazuh_*` - Wazuh data and configurations
- `lme_fleet_data` - Fleet server data
- `lme_filebeat_*` - Filebeat configurations
- `lme_elastalert2_logs` - ElastAlert logs
- `lme_backups` - Internal backup storage
- `lme_pgvectordata` - pgvector PostgreSQL data for LME doc embeddings

For **cluster installs**, `backup_lme.yml` excludes:
- `lme_esdata*`
- `lme_backups`

This keeps the host-level backup focused on master/control-plane recovery
instead of implying a local filesystem copy is a cluster-wide Elasticsearch
backup.

### 6. Podman Secrets
Two artifacts are written to make secret restoration self-contained:

- `secret_mapping.txt` (legacy): `NAME=ID` lines for each Podman secret. Older
  restore code reads this file and pulls plaintext from `/etc/lme/vault/<ID>`.
- `secret_manifest.txt` (preferred): one line per secret in the format
  `NAME|ID|DRIVER|VAULT_FILE|CAPTURED_FILE`.
  - `VAULT_FILE` points into `etc_lme/vault/` and is used for shell-driver
    secrets that already live in the LME Ansible vault (for example
    `elastic`, `kibana_system`, `wazuh`, `wazuh_api`).
  - `CAPTURED_FILE` points into `secrets/` and stores the secret value
    re-encrypted with `ansible-vault` for non-vault driver secrets such as
    `pgvector` and `llm-keys`. The cleartext is never written to disk.

If `podman secret inspect --showsecret` is unavailable for a given secret,
the manifest still records its name and ID with empty payload references, and
the restore playbooks log a warning instead of recreating it incorrectly.

### 7. Backup Metadata
- Backup timestamp and version information
- Volume manifest with contents listing
- Backup status and verification data
- Expected empty volumes list

## Backup Process

### Step-by-Step Process
1. **Pre-backup validation**
   - Checks LME installation exists
   - Verifies container files are present
   - Confirms LME service status

2. **Service management**
   - Stops LME services to ensure data consistency
   - Waits for all containers to stop completely

3. **Data backup**
   - Creates timestamped backup directory
   - Copies LME installation files
   - Backs up all Podman volumes with data verification for single-node installs
   - In cluster mode, backs up only non-Elasticsearch local volumes

4. **Service restoration**
   - Restarts LME services
   - Verifies all containers are running properly

### Backup Directory Structure
```
/var/lib/containers/storage/backups/
└── YYYYMMDDTHHMMSS/                  # Timestamp-based directory
    ├── backup_status.txt             # Backup completion status
    ├── expected_empty_volumes.txt    # List of volumes expected to be empty
    ├── secret_mapping.txt            # Legacy NAME=ID secret list
    ├── secret_manifest.txt           # NAME|ID|DRIVER|VAULT_FILE|CAPTURED_FILE
    ├── lme/                          # LME installation backup
    │   ├── lme-environment.env
    │   ├── config/
    │   └── ...
    ├── etc_lme/                      # Vault and security files backup
    │   ├── pass.sh
    │   ├── vault/
    │   └── version
    ├── etc_containers_systemd/       # Quadlet files backup
    ├── etc_systemd_system_lme/       # LME-owned host systemd units
    │   ├── manifest.txt              # UNIT|FILE_BACKED_UP|ENABLED_STATE
    │   ├── lme.service
    │   ├── lme-llm-keys.service
    │   ├── lme-llm-keys.path
    │   ├── lme-llama-model.service
    │   ├── lme-llama-model.path
    │   ├── lme-kev-sync.service
    │   └── lme-kev-sync.timer
    ├── secrets/                      # Vault-encrypted captured secret values
    │   ├── pgvector.vault
    │   └── llm-keys.vault
    └── volumes/                      # Volume backups
        ├── lme_esdata01/
        │   ├── manifest.txt          # Volume contents listing
        │   ├── backup_status.txt
        │   └── data/                 # Actual volume data
        ├── lme_kibanadata/
        ├── lme_pgvectordata/
        └── ...
```

## Usage Examples

### Basic Backup
```bash
# Navigate to ansible directory
cd ~/LME/ansible

# Run interactive backup
ansible-playbook backup_lme.yml
```

### Automated Backup (for scripts)
```bash
#!/bin/bash
cd ~/LME/ansible
ansible-playbook backup_lme.yml -e skip_prompts=true

# Check backup status
if [ $? -eq 0 ]; then
    echo "Backup completed successfully"
else
    echo "Backup failed"
    exit 1
fi
```

### Cluster Backup With Shared Snapshot Storage
```bash
cd ~/LME
ansible-playbook -i ansible/inventory/cluster.yml ansible/cluster_backup_lme.yml \
  -e es_snapshot_fs_location=/usr/share/elasticsearch/snapshots \
  -e es_snapshot_repo=lme_nfs_backups
```

### Scheduled Backups
Add to crontab for regular backups:
```bash
# Edit crontab
sudo crontab -e

# Add daily backup at 2 AM
0 2 * * * cd /root/LME/ansible && ansible-playbook backup_lme.yml -e skip_prompts=true >> /var/log/lme_backup.log 2>&1
```

## Backup Verification

### Check Backup Status
```bash
# Find latest backup
LATEST_BACKUP=$(ls -1t /var/lib/containers/storage/backups/ | head -n1)

# Check backup status
cat "/var/lib/containers/storage/backups/$LATEST_BACKUP/backup_status.txt"
```

### Verify Backup Contents
```bash
# List backup contents
ls -la "/var/lib/containers/storage/backups/$LATEST_BACKUP/"

# Check volume backups
ls -la "/var/lib/containers/storage/backups/$LATEST_BACKUP/volumes/"

# Verify LME installation backup
ls -la "/var/lib/containers/storage/backups/$LATEST_BACKUP/lme/"
```

For cluster-aware backups, also verify:
```bash
ls -la "/var/lib/containers/storage/backups/$LATEST_BACKUP/" | grep -E "cluster_recovery_manifest|cluster_recovery_note"
```

## Troubleshooting

### Common Issues

#### 1. Insufficient Disk Space
**Error**: "No space left on device"
**Solution**:
```bash
# Check available space
df -h

# Clean up old backups if needed
sudo rm -rf /var/lib/containers/storage/backups/YYYYMMDDTHHMMSS

# Clean up unused containers/images
sudo podman system prune -a
```

#### 2. Services Won't Stop
**Error**: Containers still running after stop command
**Solution**:
```bash
# Force stop all LME containers
sudo podman stop $(sudo podman ps -q --filter name=lme)

# If still running, force kill
sudo podman kill $(sudo podman ps -q --filter name=lme)

# Restart the backup
ansible-playbook backup_lme.yml
```

#### 3. Elasticsearch Fails to Start After Backup (Exit 125 / Dependent Containers)
**Error**: `lme-elasticsearch.service` fails with exit code 125 and Podman
reports "container has dependent containers which must be removed first"
**Cause**: Stale stopped containers (e.g. `lme-kibana`, `lme-setup-accts`)
still reference `lme-elasticsearch` via Podman `--requires` or
`UserNS=container:` dependencies. Podman cannot recreate
`lme-elasticsearch` until those dependents are removed.
**Solution**:
```bash
# Remove all lme-* containers in dependency order (dependents first)
for c in lme-fleet-server lme-fleet-distribution lme-elastalert2 \
         lme-wazuh-manager lme-kibana lme-setup-accts lme-setup-certs \
         lme-elasticsearch; do
  sudo podman rm -f "$c" 2>/dev/null || true
done

# Restart LME
sudo systemctl start lme
```

The `backup_lme` role handles this automatically by removing all `lme-*`
containers before restarting services. If the issue persists, run the manual
commands above.

#### 4. Permission Errors
**Error**: Permission denied accessing volumes
**Solution**:
```bash
# Ensure running as root or with sudo
sudo ansible-playbook backup_lme.yml

# Check volume permissions
sudo ls -la /var/lib/containers/storage/volumes/
```

#### 5. Backup Directory Already Exists
**Error**: Backup directory for today already exists
**Solution**:
- The playbook will prompt to overwrite
- Choose 'yes' to overwrite or 'no' to cancel
- For automated backups, existing backups are automatically overwritten

### Debug Mode
Enable verbose output for troubleshooting:
```bash
ansible-playbook backup_lme.yml -e debug_mode=true
```

### Log Analysis
```bash
# Check systemd logs for LME service
sudo journalctl -u lme.service -f

# Check container logs
sudo podman logs lme-elasticsearch
sudo podman logs lme-kibana
sudo podman logs lme-wazuh
```

## Best Practices

### 1. Regular Backup Schedule
- **Daily backups**: For production environments
- **Weekly backups**: For development/testing
- **Before changes**: Always backup before upgrades or configuration changes

### 2. Backup Retention
```bash
# Keep only last 7 backups (example cleanup script)
#!/bin/bash
BACKUP_DIR="/var/lib/containers/storage/backups"
cd "$BACKUP_DIR"
ls -1t | tail -n +8 | xargs -r rm -rf
```

### 3. Backup Verification
- Always check backup status after completion
- Periodically test restore procedures
- Monitor backup sizes for unexpected changes

### 4. Storage Management
- Monitor disk space regularly
- Consider external storage for backups
- Implement backup rotation policies

## Security Considerations

### Backup Security
- Backups contain sensitive data and encrypted passwords
- Secure backup storage location with appropriate permissions
- Consider encrypting backup directories for additional security

## Recovery Planning

### Backup Testing
Regularly test your backups by:
1. Creating a test backup
2. For single-node, performing a rollback operation
3. For clusters, testing `restore_lme_master.yml` and `restore_elasticsearch_snapshot.yml`
4. Verifying all services work correctly

### Documentation
- Document your backup procedures
- Keep backup schedules and retention policies updated
- Maintain recovery time objectives (RTO) and recovery point objectives (RPO)

## Related Operations

- **[Upgrade Operations](UPGRADE_README.md)**: Upgrading LME with backup integration
- **[Rollback Operations](ROLLBACK_README.md)**: Restoring from backups
- **[Cluster Recovery](CLUSTER_RECOVERY_README.md)**: Cluster-safe backup and restore workflows
- **[Password Rotation](PASSWORD_README.md)**: Inventory of LME credentials
  (including the `pgvector` and `llm-keys` Podman secrets captured in
  `secret_manifest.txt`) and how to rotate each one