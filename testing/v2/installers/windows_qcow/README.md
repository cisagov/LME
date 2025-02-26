# Windows VM Setup Tools

This collection of scripts sets up a Windows VM with networking, SSH, and RDP capabilities on a remote machine.

## Prerequisites
- Remote machine with minimega installed
- Access to the remote machine's IP and credentials

## Installation

From the directory containing both `windows_qcow` and `ubuntu_qcow_maker` folders `LME/testing/v2/installers`:

1. Configure environment:
```bash
cp windows_qcow/.env.example windows_qcow/.env
```

2. Copy folders to remote machine and install:
```bash
export user=lme-user
export hostname=$(cat your-group-name.ip.txt)
rsync -av windows_qcow ubuntu_qcow_maker $user@$hostname:/home/$user/
ssh $user@$hostname 
cd /home/$user/windows_qcow
sudo ./install_local.sh
```

You will be prompted to login with your Azure device code during installation.

## Script Reference

### Core Installation
- `install.sh` - Main installation orchestrator for pipeline
- `install_local.sh` - Local machine installation procedure when ssh'd into the remote machine
- `install_azure.sh` - Installs Azure CLI and dependencies
- `.env.example` - Azure credentials and configuration sample with default values
- `.env` - Azure credentials and configuration

### Azure Setup
- `get_storage_key.sh` - Retrieves Azure storage access key. Use `-p` flag to print the key to stdout
- `download_blob_file.sh` - Downloads Windows VM image from Azure

### VM Configuration
- `windows-runner.mm` - Minimega VM configuration
- `start_networking.sh` - Configures VM networking
- `set_dns.sh` - Sets up DNS for the VM
- `wait_for_cc.sh` - Waits for command and control initialization. Usage: `wait_for_cc.sh <vm_name> [-t <timeout_in_seconds>]`

### Remote Access Setup
- `setup_ssh.sh` - Installs OpenSSH Server
- `start_ssh_service.sh` - Configures SSH service
- `setup_rdp.sh` - Enables Remote Desktop access

### Monitoring & Troubleshooting
- `check_cc_active.sh` - Verifies command and control status
- `check_ssh_service.sh` - Checks SSH service configuration
- `check_system.sh` - System status verification

## Remote Access

After installation completes:
- SSH: port 22
- RDP: port 3389