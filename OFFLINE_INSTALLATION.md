# LME Offline Installation Guide

This guide explains how to perform an offline installation of LME (Logging Made Easy) when internet access is not available on the target system.

## Overview

The offline installation mode allows you to install LME on systems without internet connectivity by:
- Skipping package downloads and updates
- Skipping container image pulls
- Bypassing HIBP (Have I Been Pwned) password checks
- Using pre-downloaded/cached resources

## Prerequisites

Before performing an offline installation, you must have a system that has already downloaded all required components:

### 1. System Packages
Ensure the following packages are already installed on the target system:
- **Common packages**: curl, wget, gnupg2, sudo, git, openssh-client, expect
- **Ubuntu/Debian packages**: apt-transport-https, ca-certificates, gnupg, lsb-release, software-properties-common, fuse-overlayfs, build-essential, python3-pip, python3-pexpect, locales
- **Nix packages**: nix-bin, nix-setup-systemd

### 2. Container Images
All required container images must be pre-pulled and available locally:
```bash
# Required container images (from config/containers.txt):
docker.elastic.co/elasticsearch/elasticsearch:8.18.0
docker.elastic.co/beats/elastic-agent:8.18.0
docker.elastic.co/kibana/kibana:8.18.0
docker.io/wazuh/wazuh-manager:4.9.1
docker.io/jertel/elastalert2:2.20.0
```

### 3. Nix Packages
Ensure the following Nix packages are available:
- nixpkgs.podman
- nixpkgs.docker-compose

## Offline Installation Methods

### Method 1: Using install.sh with --offline flag

```bash
sudo ./install.sh --offline
```

Additional options can be combined:
```bash
sudo ./install.sh --offline --ip 192.168.1.100 --debug
```

### Method 2: Using Ansible directly

```bash
ansible-playbook ansible/site.yml --extra-vars '{"offline_mode": true}'
```

### Method 3: Environment Variable

Set the offline mode in your playbook variables or pass it as an extra variable:
```bash
ansible-playbook ansible/site.yml -e offline_mode=true
```

## Offline Upgrade

To upgrade LME in offline mode:

```bash
ansible-playbook ansible/upgrade_lme.yml --extra-vars '{"offline_mode": true}'
```

## What Gets Skipped in Offline Mode

### Package Management
- `apt update` commands
- Package installations via apt
- Nix channel updates
- Nix package installations

### Container Operations
- Container image pulls (`podman pull`)
- Container image downloads

### Security Checks
- HIBP (Have I Been Pwned) password breach checks
- Internet connectivity tests

### Network Operations
- External API calls
- Repository updates
- Channel synchronization

## Preparing for Offline Installation

### Step 1: Prepare Source System (with Internet)

1. **Download container images**:
```bash
# On a system with internet access
podman pull docker.elastic.co/elasticsearch/elasticsearch:8.18.0
podman pull docker.elastic.co/beats/elastic-agent:8.18.0
podman pull docker.elastic.co/kibana/kibana:8.18.0
podman pull docker.io/wazuh/wazuh-manager:4.9.1
podman pull docker.io/jertel/elastalert2:2.20.0

# Save images to tar files
podman save -o elasticsearch.tar docker.elastic.co/elasticsearch/elasticsearch:8.18.0
podman save -o elastic-agent.tar docker.elastic.co/beats/elastic-agent:8.18.0
podman save -o kibana.tar docker.elastic.co/kibana/kibana:8.18.0
podman save -o wazuh-manager.tar docker.io/wazuh/wazuh-manager:4.9.1
podman save -o elastalert2.tar docker.io/jertel/elastalert2:2.20.0
```

2. **Download system packages** (create local repository or download .deb files)

3. **Prepare Nix packages** (if using Nix-based installation)

### Step 2: Transfer to Target System

1. Copy all saved container images to the target system
2. Copy LME source code
3. Copy any downloaded packages

### Step 3: Load Resources on Target System

1. **Load container images**:
```bash
podman load -i elasticsearch.tar
podman load -i elastic-agent.tar
podman load -i kibana.tar
podman load -i wazuh-manager.tar
podman load -i elastalert2.tar
```

2. **Install system packages** (if not already installed)

3. **Verify all prerequisites are met**

## Security Considerations

### Password Security in Offline Mode
Since HIBP checks are skipped in offline mode, ensure you:
- Use strong, unique passwords (minimum 12 characters)
- Include a mix of uppercase, lowercase, numbers, and special characters
- Avoid common passwords or dictionary words
- Consider using a password manager to generate secure passwords

### Network Security
- Ensure the offline system is properly secured
- Implement appropriate firewall rules
- Monitor for any unexpected network activity

## Troubleshooting

### Common Issues

1. **Missing container images**:
   - Error: "Failed to pull container"
   - Solution: Ensure all required images are pre-loaded

2. **Missing system packages**:
   - Error: Package installation failures
   - Solution: Install required packages manually or from local repository

3. **Nix-related errors**:
   - Error: Nix channel or package issues
   - Solution: Ensure Nix is properly configured and packages are available

### Verification Commands

Check if container images are available:
```bash
podman images
```

Verify system packages:
```bash
dpkg -l | grep -E "(curl|wget|gnupg2|sudo|git)"
```

Check Nix installation:
```bash
nix-env -q
```

## Support

For issues with offline installation:
1. Check the troubleshooting section above
2. Verify all prerequisites are met
3. Review the installation logs for specific error messages
4. Ensure the offline_mode variable is properly set

## Notes

- Offline mode is designed for air-gapped or restricted network environments
- All security validations that require internet access are bypassed
- Ensure proper security measures are in place when using offline mode
- Regular security updates should be applied when internet access becomes available
