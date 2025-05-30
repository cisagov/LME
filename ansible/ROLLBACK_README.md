# LME Rollback Operations

This guide covers how to rollback your LME (Logging Made Easy) installation to a previous backup using Ansible playbooks.

## Overview

The LME rollback system provides safe restoration from backups with:
- Interactive backup selection from available backups
- Optional safety backup before rollback
- Complete restoration of configuration and data
- Service validation after rollback
- Detailed recovery instructions

## ⚠️ Space Requirements

**CRITICAL: Ensure you have sufficient disk space before running any rollback operations.**

### Space Calculation
You need **at least 3x the current LME data usage** in free space:
- 1x for the existing data
- 1x for the safety backup (if chosen)
- 1x for the backup being restored

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

### Pre-Rollback Space Check
```bash
# Get container storage root
STORAGE_ROOT=$(cat /etc/containers/storage.conf | grep graphroot | cut -d'"' -f2 || echo "/var/lib/containers/storage")

# Check available space vs required space on container storage
AVAILABLE=$(df "$STORAGE_ROOT" --output=avail | tail -n1)
USED=$(du -s "$STORAGE_ROOT" | cut -f1)
REQUIRED=$((USED * 3))

echo "Container storage space:"
echo "Available: ${AVAILABLE}KB"
echo "Required: ${REQUIRED}KB"

# Check backup directory space if it's a symlink
BACKUP_DIR="$STORAGE_ROOT/backups"
if [ -L "$BACKUP_DIR" ]; then
    BACKUP_TARGET=$(readlink -f "$BACKUP_DIR")
    BACKUP_AVAILABLE=$(df "$BACKUP_TARGET" --output=avail | tail -n1)
    SAFETY_BACKUP_REQUIRED=$USED  # Safety backup needs 1x the data size
    
    echo ""
    echo "Backup storage space (symlinked):"
    echo "Available: ${BACKUP_AVAILABLE}KB"
    echo "Required for safety backup: ${SAFETY_BACKUP_REQUIRED}KB"
    
    if [ $AVAILABLE -lt $((USED * 2)) ] || [ $BACKUP_AVAILABLE -lt $SAFETY_BACKUP_REQUIRED ]; then
        echo "⚠️  WARNING: Insufficient space for safe rollback"
        echo "Container storage needs 2x current usage, backup storage needs 1x for safety backup"
        echo "Please free up space or skip safety backup (not recommended)"
    fi
else
    if [ $AVAILABLE -lt $REQUIRED ]; then
        echo "⚠️  WARNING: Insufficient space for safe rollback"
        echo "Please free up space or skip safety backup (not recommended)"
    fi
fi
```

## Prerequisites

### Available Backups
Rollback requires existing backups created by:
- Manual backup operations: `ansible-playbook backup_lme.yml`
- Upgrade operations (when backup was chosen)
- Scheduled backup jobs

### Check Available Backups
```bash
# Get container storage root and backup directory
STORAGE_ROOT=$(cat /etc/containers/storage.conf | grep graphroot | cut -d'"' -f2 || echo "/var/lib/containers/storage")
BACKUP_DIR="$STORAGE_ROOT/backups"

# Check if backups directory is a symlink
if [ -L "$BACKUP_DIR" ]; then
    BACKUP_TARGET=$(readlink -f "$BACKUP_DIR")
    echo "Backups directory is symlinked to: $BACKUP_TARGET"
    
    # List available backups
    sudo ls -la "$BACKUP_TARGET"/
    
    # Check backup details
    sudo find "$BACKUP_TARGET"/ -name "backup_status.txt" -exec echo "=== {} ===" \; -exec cat {} \;
else
    echo "Backups directory: $BACKUP_DIR"
    
    # List available backups
    sudo ls -la "$BACKUP_DIR"/
    
    # Check backup details
    sudo find "$BACKUP_DIR"/ -name "backup_status.txt" -exec echo "=== {} ===" \; -exec cat {} \;
fi
```

## Rollback Process

### Interactive Rollback (Recommended)
```bash
cd ~/LME/ansible
ansible-playbook rollback_lme.yml
```

The playbook will:
1. **Backup Discovery**: List all available backups with version information
2. **Backup Selection**: Prompt to select which backup to restore from
3. **Safety Backup Prompt**: Ask if you want to create a safety backup (recommended)
4. **Service Management**: Stop services for safe rollback
5. **Data Restoration**: Restore configuration files and volume data
6. **Container Updates**: Pull and tag container images from backup
7. **Service Restart**: Start services with restored configuration
8. **Validation**: Verify all services are running correctly

### Backup Selection
When prompted, you'll see a list like:
```
1. 20241127T143022 (Version: Stack: 8.18.0, LME: 2.1.0)
2. 20241126T020000 (Version: Stack: 8.17.0, LME: 2.0.2)
3. 20241125T020000 (Version: Stack: 8.17.0, LME: 2.0.2)

Please enter the number of the backup to restore from (1-3):
Note: Backups are sorted by date, with the newest backup at the bottom.
```

### Safety Backup Integration

When prompted for safety backup:
- **`y` or `yes`**: Creates a safety backup before rollback (recommended)
- **`n` or `no`**: Skips safety backup (only if you're confident)

## What Gets Restored

### 1. LME Installation Directory
- **Location**: `/opt/lme/`
- **Contents**:
  - `lme-environment.env` (configuration)
  - `config/` directory with container references
  - Quadlet files

### 2. LME Vault and Security Files
- **Location**: `/etc/lme/`
- **Contents**:
  - `pass.sh` (master password for vault)
  - `vault/` directory (encrypted password files)
  - `version` file
  - Security certificates and vault data

### 3. Podman Volumes
All LME-related volumes are restored:
- `lme_esdata01` - Elasticsearch data and indices
- `lme_kibanadata` - Kibana configurations and dashboards
- `lme_certs` - SSL/TLS certificates
- `lme_wazuh_*` - Wazuh data, configurations, and logs
- `lme_fleet_data` - Fleet server data and policies
- `lme_filebeat_*` - Filebeat configurations
- `lme_elastalert2_logs` - ElastAlert logs
- Other LME volumes as they exist

### 4. Container Images
- Pulls container images referenced in the backup
- Tags images with LME_LATEST for consistency
- Ensures version compatibility

## Usage Examples

### Standard Rollback
```bash
# Navigate to ansible directory
cd ~/LME/ansible

# Run rollback with safety backup
ansible-playbook rollback_lme.yml
# Select backup number when prompted
# Choose 'y' for safety backup when prompted

# Verify rollback
sudo podman ps
cat /opt/lme/lme-environment.env | grep VERSION
```

### Emergency Rollback (Skip Safety Backup)
```bash
cd ~/LME/ansible
ansible-playbook rollback_lme.yml
# Select backup number when prompted
# Choose 'n' for safety backup (only in emergencies)
```

### Check Rollback Status
```bash
# Check rollback status file
sudo ls -la /tmp/lme_rollback_*.status
sudo cat /tmp/lme_rollback_*.status

# Verify services
sudo systemctl status lme.service
sudo podman ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
```

## Rollback Validation

### Post-Rollback Checks
```bash
# 1. Check all containers are running
sudo podman ps | grep lme

# 2. Check service status
sudo systemctl status lme.service

# 3. Check restored versions
cat /opt/lme/lme-environment.env | grep -E "(LME_VERSION|STACK_VERSION)"

# 4. Test web interfaces
curl -k https://localhost:5601  # Kibana
curl -k https://localhost:9200  # Elasticsearch

# 5. Check data integrity
# Access Kibana and verify dashboards are present
# Check Elasticsearch indices: curl -k https://localhost:9200/_cat/indices
```

### Volume Verification
```bash
# Check volume restoration
sudo podman volume ls | grep lme_

# Verify volume contents (example for Elasticsearch)
sudo podman exec lme-elasticsearch ls -la /usr/share/elasticsearch/data

# Check volume sizes match expectations
sudo podman system df -v | grep lme_
```

## Troubleshooting

### Common Issues

#### 1. No Backups Available
**Error**: "No LME backups found"
**Solution**:
```bash
# Check backup directory exists
sudo ls -la /var/lib/containers/storage/backups/

# Create a backup first
ansible-playbook backup_lme.yml

# Check backup directory permissions
sudo ls -la /var/lib/containers/storage/
```

#### 2. Insufficient Disk Space
**Error**: "No space left on device"
**Solution**:
```bash
# Check space
df -h

# Clean up old backups
sudo rm -rf /var/lib/containers/storage/backups/YYYYMMDDTHHMMSS

# Clean up unused containers/images
sudo podman system prune -a

# Skip safety backup (not recommended)
# Answer 'n' when prompted for safety backup
```

#### 3. Volume Restoration Failures
**Error**: "Volume is being used" or "Failed to restore volume"
**Solution**:
```bash
# Ensure all containers are stopped
sudo podman stop $(sudo podman ps -q --filter name=lme)

# Force remove volumes if needed
sudo podman volume rm lme_esdata01 --force

# Restart rollback
ansible-playbook rollback_lme.yml
```

#### 4. Services Won't Start After Rollback
**Error**: Containers fail to start or exit immediately
**Solution**:
```bash
# Check container logs
sudo podman logs lme-elasticsearch
sudo podman logs lme-kibana

# Check for configuration issues
sudo podman exec lme-elasticsearch cat /usr/share/elasticsearch/config/elasticsearch.yml

# Verify volume mounts
sudo podman inspect lme-elasticsearch | grep -A 10 Mounts

# Try manual container start
sudo systemctl restart lme.service
```

#### 5. Backup Selection Issues
**Error**: Invalid selection or backup not found
**Solution**:
- Enter only the number (1, 2, 3, etc.)
- Avoid extra spaces or characters
- Ensure the backup directory exists and is readable

#### 6. Safety Backup Prompt Loop
**Error**: Keeps asking for safety backup choice
**Solution**:
- Enter exactly `y`, `yes`, `n`, or `no`
- Avoid extra spaces or characters
- Use lowercase letters

### Debug Mode
Enable verbose output for troubleshooting:
```bash
ansible-playbook rollback_lme.yml -e debug_mode=true
```

### Recovery from Failed Rollback

#### If Rollback Fails with Safety Backup
```bash
# The safety backup is automatically created
# Check the rollback status file for the safety backup location
sudo cat /tmp/lme_rollback_*.status

# Manually restore from safety backup if needed
ansible-playbook rollback_lme.yml # choose the latest backup
```

#### If Rollback Fails without Safety Backup
```bash
# Try rolling back to a different backup
ansible-playbook rollback_lme.yml
# Select a different, older backup

# If all else fails, restore from the most recent working backup
# This may result in some data loss
```

## Best Practices

### 1. Pre-Rollback Preparation
```bash
# Document current state
sudo podman ps > /tmp/pre_rollback_containers.txt
cat /opt/lme/lme-environment.env > /tmp/pre_rollback_env.txt

# Verify backup integrity
sudo find /var/lib/containers/storage/backups/ -maxdepth 2 -name "backup_status.txt" -not -path "*/volumes/*" -exec echo "=== {} ===" \; -exec cat {} \;
```

### 2. Rollback Timing
- **Emergency Response**: Rollback immediately if critical issues occur
- **Planned Rollback**: Schedule during maintenance windows
- **Testing**: Test rollback procedures in development environment

### 3. Safety Backup Strategy
- **Always recommended**: Create safety backup unless in emergency
- **Disk space**: Ensure sufficient space for safety backup
- **Retention**: Clean up safety backups after confirming successful rollback

### 4. Monitoring During Rollback
```bash
# Monitor in separate terminal
watch 'sudo podman ps --format "table {{.Names}}\t{{.Status}}"'

# Monitor logs
sudo journalctl -u lme.service -f

# Monitor rollback status
watch 'sudo tail -n 20 /tmp/lme_rollback_*.status'
```

## Recovery Scenarios

### Scenario 1: Failed Upgrade
```bash
# Upgrade failed, need to rollback
ansible-playbook rollback_lme.yml
# Select the backup created before the upgrade
# Choose 'y' for safety backup
```

### Scenario 2: Data Corruption
```bash
# Data corruption detected, rollback to last known good state
ansible-playbook rollback_lme.yml
# Select the most recent backup before corruption
# Choose 'y' for safety backup
```

### Scenario 3: Configuration Issues
```bash
# Configuration changes caused problems
ansible-playbook rollback_lme.yml
# Select backup from before configuration changes
# Choose 'y' for safety backup
```

### Scenario 4: Testing Rollback Procedures
```bash
# Create test backup
ansible-playbook backup_lme.yml

# Perform rollback test
ansible-playbook rollback_lme.yml
# Select an older backup
# Choose 'y' for safety backup

# Verify rollback worked
# Rollback to the test backup to restore current state
ansible-playbook rollback_lme.yml
# Select the test backup created at the beginning
```

## Security Considerations

### Backup Security
- Rollback restores encrypted passwords and certificates
- Ensure backup directories have proper permissions
- Verify backup integrity before rollback

### Access Control
```bash
# Secure backup and rollback operations
sudo chmod 700 /var/lib/containers/storage/backups
sudo chown root:root /var/lib/containers/storage/backups

# Secure rollback status files
sudo chmod 600 /tmp/lme_rollback_*.status
```

## Performance Impact

### During Rollback
- **Downtime**: 10-30 minutes depending on data size
- **Resource Usage**: High I/O during volume restoration
- **Network**: Bandwidth usage for container image pulls

### After Rollback
- Performance should match the backup's original state
- Monitor for any performance issues
- Verify all functionality is restored

## Cleanup After Rollback

### Safety Backup Cleanup
```bash
# After confirming successful rollback, clean up safety backup
# Check rollback status for safety backup location
sudo cat /tmp/lme_rollback_*.status

# Remove safety backup (only after confirming rollback success)
sudo rm -rf /var/lib/containers/storage/backups/SAFETY_BACKUP_TIMESTAMP
```

### Status File Cleanup
```bash
# Clean up rollback status files after review
sudo rm /tmp/lme_rollback_*.status
```

## Related Operations

- **[Backup Operations](BACKUP_README.md)**: Creating backups for rollback
- **[Upgrade Operations](UPGRADE_README.md)**: Upgrading with rollback safety
- **[Main README](README.md)**: Overview of all LME Ansible operations

## Support and Documentation

### Getting Help
- Check rollback status file: `sudo cat /tmp/lme_rollback_*.status`
- Review container logs: `sudo podman logs <container_name>`
- Enable debug mode for detailed output

### Documentation
- Keep rollback logs for analysis
- Document rollback procedures and timings
- Maintain rollback testing schedules 