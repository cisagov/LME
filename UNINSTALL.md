# LME Uninstall Guide

This guide explains how to completely remove LME (Logging Made Easy) from your system.

## Overview

The uninstall script (`scripts/uninstall_lme.sh`) provides a safe and comprehensive way to remove all LME components from your system. This is useful when:

- You want to start over with a fresh installation
- You're testing different installation configurations
- You need to completely remove LME from a system
- You're troubleshooting installation issues

## Quick Start

```bash
sudo ./scripts/uninstall_lme.sh
```

The script will:
1. Ask for confirmation before proceeding
2. Show you exactly what will be removed
3. Perform a step-by-step uninstallation with progress reporting
4. Provide a summary of what was removed and what remains

## What Gets Removed

### 1. Systemd Services
- `lme.service` - Main LME orchestrator service
- All LME container services (elasticsearch, kibana, wazuh, fleet, etc.)
- Service files from `/etc/systemd/system/`

### 2. Containers
All LME containers are stopped and removed:
- `lme-elasticsearch`
- `lme-kibana`
- `lme-wazuh-manager`
- `lme-fleet-server`
- `lme-elastalert2`
- `lme-setup-certs`
- `lme-setup-accts`
- `lme-fleet-distribution` (offline mode)

### 3. Volumes (ALL DATA IS DELETED)
All LME volumes and their data are permanently removed:
- `lme_esdata01` - Elasticsearch data and indices
- `lme_kibanadata` - Kibana configurations and dashboards
- `lme_certs` - SSL/TLS certificates
- `lme_backups` - Elasticsearch backups
- `lme_fleet_data` - Fleet server data
- `lme_wazuh_*` - Wazuh configurations, logs, and data
- `lme_filebeat_*` - Filebeat configurations
- `lme_elastalert2_logs` - ElastAlert logs

**⚠️ WARNING:** All log data, dashboards, and configurations stored in these volumes will be permanently deleted!

### 4. Secrets
All LME secrets are removed:
- `elastic` - Elasticsearch admin password
- `kibana_system` - Kibana system password
- `wazuh` - Wazuh password
- `wazuh_api` - Wazuh API password

### 5. Container Images
All LME container images are removed:
- `localhost/elasticsearch:LME_LATEST`
- `localhost/kibana:LME_LATEST`
- `localhost/elastic-agent:LME_LATEST`
- `localhost/wazuh-manager:LME_LATEST`
- `localhost/elastalert2:LME_LATEST`
- `localhost/package-registry:LME_LATEST` (offline mode)

### 6. Configuration Files
- `/opt/lme/` - All LME configuration and data
- `/etc/lme/` - LME system configuration
- `/etc/containers/systemd/lme-*` - Quadlet files

### 7. Systemd Generator Symlinks
- `/usr/libexec/podman/quadlet`
- `/usr/lib/systemd/system-generators/podman-system-generator`

## What Does NOT Get Removed

The following components remain on your system after uninstallation:

### 1. Nix Package Manager
- `/nix/` directory and all Nix packages
- Nix daemon service
- PATH modifications in user profiles

**Reason:** Nix may be used by other applications, and removing it could break them.

### 2. Podman
- Podman installation and binaries
- Podman configuration (except LME-specific configs)

**Reason:** Podman is a system-level container runtime that may be used by other applications.

### 3. System Packages
- Ansible
- Other packages installed during LME setup

**Reason:** These are general-purpose tools that may be needed for other purposes.

### 4. System Configuration
- Sysctl settings in `/etc/sysctl.conf`:
  - `vm.max_map_count = 262144`
  - `net.core.rmem_max = 7500000`
  - `net.core.wmem_max = 7500000`
- User limits in `/etc/security/limits.conf`
- Subuid/subgid mappings in `/etc/subuid` and `/etc/subgid`

**Reason:** These settings are generally safe to leave in place and may benefit other applications.

### 5. User Container Configurations
- `~/.config/containers/` - User-specific container configurations

**Reason:** May contain configurations for other container workloads.

### 6. Offline Resources (if present)
- `offline_resources/` directory in the LME clone directory

**Reason:** This is part of your LME repository clone, not a system installation.

## Manual Cleanup (Optional)

If you want to completely remove everything LME-related, including the items listed above, you can manually remove them:

### Remove Nix (Optional)
```bash
# Stop nix daemon
sudo systemctl stop nix-daemon.socket nix-daemon.service
sudo systemctl disable nix-daemon.socket nix-daemon.service

# Remove Nix
sudo rm -rf /nix

# Remove Nix from user profiles
sed -i '/nix/d' ~/.profile ~/.bashrc /root/.profile /root/.bashrc
```

### Remove Podman (Optional)
```bash
# Ubuntu/Debian
sudo apt-get remove --purge podman

# RHEL/AlmaLinux/Rocky
sudo dnf remove podman
```

### Remove Sysctl Settings (Optional)
```bash
# Edit /etc/sysctl.conf and remove LME-related lines
sudo vim /etc/sysctl.conf

# Apply changes
sudo sysctl -p
```

### Remove User Limits (Optional)
```bash
# Edit /etc/security/limits.conf and remove LME-related lines
sudo vim /etc/security/limits.conf
```

## Usage Examples

### Standard Uninstall
```bash
cd /path/to/LME
sudo ./scripts/uninstall_lme.sh
```

### Uninstall and Reinstall
```bash
# Uninstall
sudo ./scripts/uninstall_lme.sh

# Reinstall (normal mode)
sudo ./install.sh

# Or reinstall (offline mode)
sudo ./install.sh --offline
```

### Uninstall for Testing
```bash
# Test installation
sudo ./install.sh --offline

# If something goes wrong, uninstall and try again
sudo ./scripts/uninstall_lme.sh
sudo ./install.sh --offline
```

## Troubleshooting

### Script Fails to Stop Services
If services won't stop:
```bash
# Force kill all LME containers
sudo podman kill $(sudo podman ps -a --format "{{.Names}}" | grep "^lme-")

# Then run uninstall again
sudo ./scripts/uninstall_lme.sh
```

### Volumes Won't Delete
If volumes are in use:
```bash
# Ensure all containers are stopped
sudo systemctl stop lme.service
sudo podman stop $(sudo podman ps -a -q)

# Force remove volumes
sudo podman volume rm -f $(sudo podman volume ls --format "{{.Name}}" | grep "^lme_")
```

### Permission Denied Errors
Ensure you're running with sudo:
```bash
sudo ./scripts/uninstall_lme.sh
```

### Podman Not Found
If podman is not in PATH:
```bash
export PATH=$PATH:/nix/var/nix/profiles/default/bin
sudo -E ./scripts/uninstall_lme.sh
```

## Backup Before Uninstall

If you want to preserve your data before uninstalling, create a backup first:

```bash
# Create backup
cd ansible
ansible-playbook backup_lme.yml

# Uninstall
cd ..
sudo ./scripts/uninstall_lme.sh

# Later, restore from backup after reinstalling
cd ansible
ansible-playbook rollback_lme.yml
```

## Verification

After uninstalling, verify that LME is completely removed:

```bash
# Check for running services
systemctl list-units | grep lme

# Check for containers
sudo podman ps -a | grep lme

# Check for volumes
sudo podman volume ls | grep lme

# Check for images
sudo podman images | grep LME_LATEST

# Check for configuration
ls -la /opt/lme /etc/lme 2>/dev/null
```

All of these commands should return no results.

## See Also

- [Installation Guide](README.md)
- [Offline Installation Guide](OFFLINE_INSTALLATION.md)
- [Backup Guide](ansible/BACKUP_README.md)
- [Rollback Guide](ansible/ROLLBACK_README.md)
- [Upgrade Guide](ansible/UPGRADE_README.md)

