# LME Backup Operations

This guide covers how to create backups of your LME (Logging Made Easy) installation using Ansible playbooks.

## Overview

The LME backup system creates comprehensive backups of your entire LME installation, including:
- Configuration files and environment settings
- All Podman volumes containing data (Elasticsearch indices, Kibana configurations, Wazuh data, etc.)
- Container image references and versions
- Security certificates and vault data

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

## What Gets Backed Up

### 1. LME Installation Directory
- **Location**: `/opt/lme/`
- **Contents**:
  - `lme-environment.env` (configuration)
  - `config/` directory
  - Quadlet files

### 2. LME Vault and Security Files
- **Location**: `/etc/lme/`
- **Contents**:
  - `pass.sh` (master password for vault)
  - `vault/` directory (encrypted password files)
  - `version` file
  - Security certificates and vault data

### 3. Podman Volumes
All LME-related volumes are backed up:
- `lme_esdata01` - Elasticsearch data
- `lme_kibanadata` - Kibana configurations
- `lme_certs` - SSL/TLS certificates
- `lme_wazuh_*` - Wazuh data and configurations
- `lme_fleet_data` - Fleet server data
- `lme_filebeat_*` - Filebeat configurations
- `lme_elastalert2_logs` - ElastAlert logs
- `lme_backups` - Internal backup storage

### 4. Backup Metadata
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
   - Backs up all Podman volumes with data verification

4. **Service restoration**
   - Restarts LME services
   - Verifies all containers are running properly

### Backup Directory Structure
```
/var/lib/containers/storage/backups/
└── YYYYMMDDTHHMMSS/           # Timestamp-based directory
    ├── backup_status.txt      # Backup completion status
    ├── expected_empty_volumes.txt  # List of volumes expected to be empty
    ├── lme/                   # LME installation backup
    │   ├── lme-environment.env
    │   ├── config/
    │   └── ...
    ├── etc_lme/               # Vault and security files backup
    │   ├── pass.sh
    │   ├── vault/
    │   └── version
    └── volumes/               # Volume backups
        ├── lme_esdata01/
        │   ├── manifest.txt   # Volume contents listing
        │   ├── backup_status.txt
        │   └── data/          # Actual volume data
        ├── lme_kibanadata/
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

#### 3. Permission Errors
**Error**: Permission denied accessing volumes
**Solution**:
```bash
# Ensure running as root or with sudo
sudo ansible-playbook backup_lme.yml

# Check volume permissions
sudo ls -la /var/lib/containers/storage/volumes/
```

#### 4. Backup Directory Already Exists
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
2. Performing a rollback operation
3. Verifying all services work correctly
4. Rolling back to original state

### Documentation
- Document your backup procedures
- Keep backup schedules and retention policies updated
- Maintain recovery time objectives (RTO) and recovery point objectives (RPO)

## Related Operations

- **[Upgrade Operations](UPGRADE_README.md)**: Upgrading LME with backup integration
- **[Rollback Operations](ROLLBACK_README.md)**: Restoring from backups