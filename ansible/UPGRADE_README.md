# LME Upgrade Operations

This guide covers how to upgrade your LME (Logging Made Easy) installation to newer versions using Ansible playbooks.

## Overview

The LME upgrade system provides safe, automated upgrades with:
- Version compatibility checking
- Optional backup creation before upgrade
- Container image updates
- Configuration migration
- Service validation after upgrade

## ⚠️ Space Requirements

**CRITICAL: Ensure you have sufficient disk space before running any upgrade operations.**

### Space Calculation
You need **at least 3x the current LME data usage** in free space:
- 1x for the existing data
- 1x for the backup (if chosen)
- 1x for new container images during upgrade

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

### Pre-Upgrade Space Check
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
    BACKUP_REQUIRED=$USED  # Backup needs 1x the data size
    
    echo ""
    echo "Backup storage space (symlinked):"
    echo "Available: ${BACKUP_AVAILABLE}KB"
    echo "Required: ${BACKUP_REQUIRED}KB"
    
    if [ $AVAILABLE -lt $((USED * 2)) ] || [ $BACKUP_AVAILABLE -lt $BACKUP_REQUIRED ]; then
        echo "⚠️  WARNING: Insufficient space for safe upgrade"
        echo "Container storage needs 2x current usage, backup storage needs 1x"
        echo "Please free up space or skip backup (not recommended)"
    fi
else
    if [ $AVAILABLE -lt $REQUIRED ]; then
        echo "⚠️  WARNING: Insufficient space for safe upgrade"
        echo "Please free up space or skip backup (not recommended)"
    fi
fi
```

## Version Management

### Check Current Version
```bash
# Check current LME version
cd ~/LME
./scripts/upgrade/detect_version.sh

# Or check manually
cat /opt/lme/lme-environment.env | grep LME_VERSION
```

### Supported Upgrade Paths
- **From 2.0.x to 2.1.0**: Supported
- **From 1.x to 2.x**: Not supported (requires manual migration)
- **Downgrades**: Not supported (use rollback instead)

## Upgrade Process

### Interactive Upgrade (Recommended)
```bash
cd ~/LME/ansible
ansible-playbook upgrade_lme.yml
```

The playbook will:
1. **Version Check**: Verify current version and upgrade compatibility
2. **Backup Prompt**: Ask if you want to create a backup (recommended)
3. **Service Management**: Stop services for safe upgrade
4. **Container Updates**: Pull and tag new container images
5. **Configuration Updates**: Update environment files and configurations
6. **Service Restart**: Start services with new versions
7. **Validation**: Verify all services are running correctly

### Automated Upgrade
For scripted environments (backup choice will still be prompted):
```bash
cd ~/LME/ansible
ansible-playbook upgrade_lme.yml
```

## Backup Integration

### Backup Recommendation
**STRONGLY RECOMMENDED**: Always create a backup before upgrading.

When prompted:
- **`y` or `yes`**: Creates a full backup before upgrade (recommended)
- **`n` or `no`**: Skips backup (only if you have recent backups)

### Backup Process During Upgrade
If you choose to backup:
1. Services are stopped
2. Full backup is created (installation + volumes)
3. Services remain stopped for upgrade
4. Upgrade continues with new images

If you skip backup:
1. Services are stopped for upgrade
2. No backup is created
3. Upgrade continues immediately

## What Gets Upgraded

### 1. Container Images
- Elasticsearch
- Kibana  
- Wazuh
- Fleet Server
- ElastAlert2

### 2. Configuration Files
- `lme-environment.env` (version numbers updated)
- `containers.txt` (new image references)
- Quadlet configurations (if needed)

### 3. Version Tracking
- `LME_VERSION` in environment file
- `STACK_VERSION` for Elasticsearch stack
- `/etc/lme/version` file

## Usage Examples

### Standard Upgrade
```bash
# Navigate to ansible directory
cd ~/LME/ansible

# Run upgrade with backup
ansible-playbook upgrade_lme.yml
# When prompted for backup: y

# Verify upgrade
sudo podman ps
cat /opt/lme/lme-environment.env | grep VERSION
```

### Upgrade Without Backup (Not Recommended)
```bash
cd ~/LME/ansible
ansible-playbook upgrade_lme.yml
# When prompted for backup: n
```

### Check Upgrade Status
```bash
# Check if upgrade is needed
cd ~/LME
./scripts/upgrade/detect_version.sh

# Check running containers
sudo podman ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"

# Verify services
sudo systemctl status lme.service
```

## Upgrade Validation

### Post-Upgrade Checks
```bash
# 1. Check all containers are running
sudo podman ps | grep lme

# 2. Check service status
sudo systemctl status lme.service

# 3. Check versions
cat /opt/lme/lme-environment.env | grep -E "(LME_VERSION|STACK_VERSION)"

# 4. Test web interfaces
curl -k https://localhost:5601  # Kibana
curl -k https://localhost:9200  # Elasticsearch
```

### Service Verification
```bash
# Check container health
sudo podman healthcheck run lme-elasticsearch
sudo podman healthcheck run lme-kibana

# Check logs for errors
sudo podman logs lme-elasticsearch --tail 50
sudo podman logs lme-kibana --tail 50
sudo podman logs lme-wazuh --tail 50
```

## Troubleshooting

### Common Issues

#### 1. Insufficient Disk Space
**Error**: "No space left on device"
**Solution**:
```bash
# Check space
df -h

# Clean up old images
sudo podman image prune -a

# Remove old backups if needed
sudo rm -rf /var/lib/containers/storage/backups/YYYYMMDDTHHMMSS

# Skip backup during upgrade (not recommended)
# Answer 'n' when prompted for backup
```

#### 2. Version Compatibility Error
**Error**: "Downgrade not allowed" or "Unsupported version"
**Solution**:
```bash
# Check current version
cat /opt/lme/lme-environment.env | grep LME_VERSION

# If downgrade needed, use rollback instead
ansible-playbook rollback_lme.yml
```

#### 3. Container Pull Failures
**Error**: Failed to pull container images
**Solution**:
```bash
# Check internet connectivity
ping docker.io

# Manually pull images
sudo podman pull docker.elastic.co/elasticsearch/elasticsearch:8.18.0

# Check container registry access
sudo podman login docker.elastic.co

# Retry upgrade
ansible-playbook upgrade_lme.yml
```

#### 4. Services Won't Start After Upgrade
**Error**: Containers fail to start or exit immediately
**Solution**:
```bash
# Check container logs
sudo podman logs lme-elasticsearch
sudo podman logs lme-kibana

# Check for configuration issues
sudo podman exec lme-elasticsearch cat /usr/share/elasticsearch/config/elasticsearch.yml

# Rollback if needed
ansible-playbook rollback_lme.yml
```

#### 5. Backup Prompt Loop
**Error**: Keeps asking for backup choice
**Solution**:
- Enter exactly `y`, `yes`, `n`, or `no`
- Avoid extra spaces or characters
- Use lowercase letters

### Debug Mode
Enable verbose output for troubleshooting:
```bash
ansible-playbook upgrade_lme.yml -e debug_mode=true
```

### Recovery from Failed Upgrade

#### If Upgrade Fails After Backup
```bash
# Rollback to the backup created during upgrade
ansible-playbook rollback_lme.yml
# Select the backup created just before the upgrade
```

#### If Upgrade Fails Without Backup
```bash
# Rollback to most recent available backup
ansible-playbook rollback_lme.yml
# Select the most recent backup available

# If no backups available, reinstall
# (This will lose data - avoid by always backing up)
```

## Best Practices

### 1. Pre-Upgrade Preparation
```bash
# Always check current status
sudo systemctl status lme.service
sudo podman ps

# Create manual backup if needed
ansible-playbook backup_lme.yml

# Check available space
df -h

# Review upgrade notes
cat ~/LME/CHANGELOG.md
```

### 2. Upgrade Timing
- **Maintenance Windows**: Schedule during low-usage periods
- **Business Hours**: Avoid upgrades during critical business operations
- **Testing**: Test upgrades in development environment first

### 3. Rollback Planning
- Always have a rollback plan
- Know your Recovery Time Objective (RTO)
- Test rollback procedures regularly

### 4. Monitoring During Upgrade
```bash
# Monitor in separate terminal
watch 'sudo podman ps --format "table {{.Names}}\t{{.Status}}"'

# Monitor logs
sudo journalctl -u lme.service -f
```

## Version-Specific Notes

### Upgrading to 2.1.0
- **New Features**: Enhanced backup/rollback system
- **Breaking Changes**: None
- **Special Considerations**: First version with automated upgrade support

### Future Versions
- Check release notes for version-specific requirements
- Review breaking changes before upgrading
- Test in development environment first

## Security Considerations

### Upgrade Security
- Upgrades may include security patches
- Review security advisories before upgrading
- Ensure all components are updated together

### Credential Management
- Passwords remain encrypted during upgrade
- No credential changes required
- Vault keys are preserved

## Performance Impact

### During Upgrade
- **Downtime**: 5-15 minutes typical
- **Resource Usage**: Higher CPU/memory during container pulls
- **Network**: Bandwidth usage for image downloads

### After Upgrade
- Performance should match or improve over previous version
- Monitor resource usage for first 24 hours
- Check for any performance regressions

## Related Operations

- **[Backup Operations](BACKUP_README.md)**: Creating backups before upgrade
- **[Rollback Operations](ROLLBACK_README.md)**: Rolling back failed upgrades
- **[Main README](README.md)**: Overview of all LME Ansible operations

## Support and Documentation

### Getting Help
- Check logs first: `sudo journalctl -u lme.service`
- Review container logs: `sudo podman logs <container_name>`
- Enable debug mode for detailed output

### Documentation
- Keep upgrade logs for troubleshooting
- Document any custom configurations
- Maintain upgrade schedules and procedures 