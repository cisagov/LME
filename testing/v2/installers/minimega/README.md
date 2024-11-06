# MinimegaSetup Scripts

This repository contains a collection of scripts to automate the setup and installation of Minimega, a powerful tool for orchestrating and managing large-scale virtual machine experiments.

## Scripts Overview

1. `copy_ssh_key.sh`: Copies an SSH key to a remote server.
1. `create_bridge.sh`: Creates a network bridge for Minimega.
1. `install.sh`: Main installation script for setting up Minimega on a remote server.
1. `install_local.sh`: Installs Minimega on the local machine.
1. `set_gopath.sh`: Sets up the GOPATH for Go programming.
1. `update_packages.sh`: Updates and installs necessary packages.
1. `fix_dnsmasq.sh`: Stops and disables the dnsmasq service.

## Usage

### Remote Installation

To install Minimega on a remote server, use the `install.sh` script:

```bash
./install.sh <username> <hostname> <password_file>
```

This script will:
- Copy the SSH key to the remote server
- Copy the Minimega directory to the remote server
- Update packages and reboot the server
- Set up DNS, GOPATH, and install Minimega
- Configure and start Minimega and Miniweb services
- Create a network bridge

### Local Installation
Note: I don't have a machine to test this on but it follows the same pattern as the remote script.  

To install Minimega on your local machine, use the `install_local.sh` script:


```bash
sudo ./install_local.sh
```

This script performs similar operations as the remote installation but on the local machine.

## Individual Scripts

- `copy_ssh_key.sh`: Copies an SSH key to a remote server. Usage: `./copy_ssh_key.sh <username> <hostname> <password_file>`
- `create_bridge.sh`: Creates a network bridge named `mega_bridge`.
- `set_gopath.sh`: Sets up the GOPATH for a specified user. Usage: `sudo ./set_gopath.sh <username>`
- `update_packages.sh`: Updates the system and installs necessary packages. Run with sudo.
- `fix_dnsmasq.sh`: Stops and disables the dnsmasq service. Run with sudo.

## Requirements

- These scripts are designed to run on a Debian-based Linux system.
- sudo privileges are required for many operations.
- For remote installation, SSH access to the target server is necessary.

## Notes

- The `install.sh` script will reboot the remote server during the installation process.
- Make sure to review and understand each script before running, especially when using sudo privileges.
- The `password_file` used in `copy_ssh_key.sh` and `install.sh` should contain the SSH password for the remote server.

## Disclaimer

These scripts make significant changes to system configurations. Always test in a safe environment before using in production.