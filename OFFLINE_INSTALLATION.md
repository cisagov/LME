# LME Offline Installation Guide

This guide explains how to install LME (Logging Made Easy) on systems without internet access (air-gapped environments).

## Overview

The offline installation process consists of two phases:

1. **Preparation Phase** (on a system with internet access)
   - Download all required resources
   - Create an offline installation archive

2. **Installation Phase** (on the offline/air-gapped system)
   - Transfer and extract the archive
   - Run the offline installation

## Supported Operating Systems

- Ubuntu 24.04 LTS
- RedHat Enterprise Linux 9 (RHEL 9)
- AlmaLinux 9
- Rocky Linux 9

**Note:** Ubuntu 22.04 is not a priority for offline installation support.

## Prerequisites

### On the Preparation System (with internet)
- Same OS as the target offline system (Ubuntu 24.04 or RHEL 9)
- Sufficient disk space (~10-15 GB for all resources)
- Internet connectivity
- `wget`, `curl`, `tar`, `gzip` installed
- Podman installed (or will be installed automatically)

### On the Target Offline System
- Same OS as used for preparation
- Sufficient disk space (~20 GB recommended)
- Ansible pre-installed (cannot be installed offline automatically)

## Phase 1: Preparation (Internet-Connected System)

### Step 1: Clone the LME Repository

```bash
git clone https://github.com/cisagov/LME.git
cd LME
git checkout offline-installation-full  # or your target branch
```

### Step 2: Run the Offline Preparation Script

```bash
cd scripts
sudo ./prepare_offline.sh
```

This script will:
- Detect your operating system
- Install podman temporarily if needed
- Download all container images (Elasticsearch, Kibana, Wazuh, Fleet, etc.)
- Download system packages (.deb for Ubuntu, .rpm for RHEL)
- Download Nix package manager and podman packages
- Download agent installers (Elastic Agent and Wazuh Agent for Windows, Linux)
- Download CVE database for offline vulnerability detection
- Generate installation scripts
- Create a compressed archive: `lme-offline-<OS>-<VERSION>-<TIMESTAMP>.tar.gz`

**Expected Duration:** 30-60 minutes depending on internet speed

**Archive Size:** Approximately 5-8 GB compressed

### Step 3: Transfer the Archive

Transfer the generated `lme-offline-*.tar.gz` file to your offline system using:
- USB drive
- Secure file transfer
- Physical media
- Any approved air-gap transfer method

## Phase 2: Installation (Offline System)

### Step 1: Prepare the Offline System

**IMPORTANT:** Ansible must be pre-installed on the offline system.

#### For Ubuntu 24.04:
```bash
# If you have access to local package repositories:
sudo apt-get update
sudo apt-get install -y ansible

# Or install from a .deb package transferred separately
```

#### For RHEL/AlmaLinux/Rocky:
```bash
# If you have access to local package repositories:
sudo dnf install -y ansible

# Or install from an .rpm package transferred separately
```

### Step 2: Extract the Offline Archive

```bash
# Transfer the archive to your offline system
# Then extract it:
tar -xzf lme-offline-*.tar.gz
cd LME
```

### Step 3: Configure Environment

```bash
# Copy the example environment file
cp config/example.env config/lme-environment.env

# Edit the configuration
vim config/lme-environment.env
```

**Required Configuration:**
- Set `IPVAR` to your server's IP address
- Review and adjust other settings as needed
- Ensure `STACK_VERSION` and `WAZUH_VERSION` match the downloaded resources

### Step 4: Run Offline Installation

```bash
sudo ./install.sh --offline
```

This will:
1. Validate offline resources
2. Install system packages from the offline cache
3. Set up Nix package manager
4. Load container images from the archive
5. Configure LME services
6. Set up the CVE database for offline vulnerability detection
7. Run Ansible playbooks in offline mode (skipping internet-dependent tasks)

**Expected Duration:** 20-40 minutes

## What Happens in Offline Mode

### Skipped Operations
The following operations are automatically skipped in offline mode:
- Package repository updates (`apt update`, `dnf update`)
- Package downloads from internet repositories
- Container image pulls from Docker Hub / Elastic registry
- Nix channel updates
- HIBP (Have I Been Pwned) password breach checks
- Online CVE database updates

### Offline Alternatives
Instead, the installation uses:
- Pre-downloaded system packages from `offline_resources/packages/`
- Pre-downloaded container images from `offline_resources/containers/`
- Pre-downloaded Nix packages from `offline_resources/nix/`
- Local CVE database from `offline_resources/cve/`
- Local Fleet package registry (for air-gapped Kibana)

## Fleet Configuration for Offline Mode

In offline mode, Kibana is automatically configured for air-gapped operation:
- Fleet package registry points to local container: `http://lme-fleet-distribution:8080`
- Air-gapped mode enabled: `xpack.fleet.isAirGapped: true`
- Fleet distribution container serves packages locally

## Agent Installation (Offline)

Agent installers are included in the offline archive at:
```
offline_resources/agents/
├── elastic-agent-<VERSION>-windows-x86_64.zip
├── elastic-agent-<VERSION>-amd64.deb
├── elastic-agent-<VERSION>-x86_64.rpm
├── elastic-agent-<VERSION>-linux-x86_64.tar.gz
├── wazuh-agent-<VERSION>-windows-amd64.msi
├── wazuh-agent_<VERSION>-1_amd64.deb
└── wazuh-agent-<VERSION>-1.x86_64.rpm
```

Transfer these to your client systems and install according to the standard LME agent installation procedures.

## Troubleshooting

### Preparation Phase Issues

**Problem:** `prepare_offline.sh` fails to download containers
- **Solution:** Ensure podman is installed and running
- **Solution:** Check internet connectivity
- **Solution:** Verify container registry access

**Problem:** Insufficient disk space
- **Solution:** Free up space or use a different directory with more space
- **Solution:** Modify `OUTPUT_DIR` in the script

### Installation Phase Issues

**Problem:** "Ansible is not installed" error
- **Solution:** Install Ansible before running offline installation
- **Solution:** Transfer Ansible package separately and install it

**Problem:** "Offline resources directory not found"
- **Solution:** Ensure you extracted the archive completely
- **Solution:** Run `install.sh --offline` from the LME directory

**Problem:** Container load fails
- **Solution:** Verify the containers tar file exists and is not corrupted
- **Solution:** Check available disk space

**Problem:** Package installation fails
- **Solution:** Ensure all dependencies are in the offline package cache
- **Solution:** Re-run `prepare_offline.sh` on the preparation system

## Verification

After installation, verify the system is working:

```bash
# Check container status
sudo podman ps

# Check service status
sudo systemctl status lme.service

# Access Kibana (from a browser)
https://<YOUR_IP>:5601

# Check Elasticsearch
curl -k -u elastic:<password> https://localhost:9200
```

## Updating Offline Installations

To update an offline installation:
1. Run `prepare_offline.sh` again on an internet-connected system with the new version
2. Transfer the new archive to the offline system
3. Follow the upgrade procedures in `ansible/UPGRADE_README.md` with the `--offline` flag

## Security Considerations

- Offline installations skip HIBP password breach checks
- Ensure strong passwords are used for all services
- CVE database should be updated periodically by re-running preparation
- Agent installers should be verified before deployment

## Support

For issues specific to offline installation:
1. Check this documentation
2. Review logs in `/var/log/` and container logs
3. Consult the main LME documentation
4. Open an issue on GitHub with `[OFFLINE]` in the title

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Offline LME System                        │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Elasticsearch│  │   Kibana     │  │    Wazuh     │      │
│  │  (Local)     │  │  (Local)     │  │  (Local)     │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│         │                  │                  │              │
│         └──────────────────┴──────────────────┘              │
│                            │                                 │
│                  ┌─────────▼─────────┐                       │
│                  │  Fleet Server     │                       │
│                  │    (Local)        │                       │
│                  └─────────┬─────────┘                       │
│                            │                                 │
│                  ┌─────────▼─────────┐                       │
│                  │ Fleet Package     │                       │
│                  │  Distribution     │                       │
│                  │  (Offline Mode)   │                       │
│                  └───────────────────┘                       │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │         Offline Resources (Local Storage)              │ │
│  ├────────────────────────────────────────────────────────┤ │
│  │ • Container Images                                     │ │
│  │ • System Packages (.deb/.rpm)                          │ │
│  │ • Nix Packages                                         │ │
│  │ • Agent Installers                                     │ │
│  │ • CVE Database                                         │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

## Uninstalling LME

If you need to completely remove LME and start over (useful for testing offline installations):

```bash
sudo ./scripts/uninstall_lme.sh
```

This script will:
- Stop and disable all LME services
- Remove all containers and images
- **Delete all volumes and data** (Elasticsearch indices, Kibana dashboards, Wazuh logs, etc.)
- Remove all secrets
- Clean up configuration files
- Remove quadlet files and systemd services

**What is NOT removed:**
- Nix package manager (`/nix`)
- Podman installation
- System packages (ansible, etc.)
- Sysctl settings
- User limits configuration

After uninstalling, you can run `install.sh` or `install.sh --offline` again for a fresh installation.

## Additional Resources

- Main LME Documentation: `README.md`
- Upgrade Guide: `ansible/UPGRADE_README.md`
- Rollback Guide: `ansible/ROLLBACK_README.md`
- Backup Guide: `ansible/BACKUP_README.md`
- Uninstall Script: `scripts/uninstall_lme.sh`

