# Ubuntu QCOW Maker

This project contains a set of scripts to create and manage Ubuntu QCOW2 images and virtual machines using Minimega. The main purpose is to simplify the process of setting up and running Ubuntu VMs on a remote machine.

## Quick Start

To set up everything on a remote machine, use the `install.sh` script:

```bash
./install.sh <username> <hostname> <password_file>
```

Replace `<username>`, `<hostname>`, and `<password_file>` with appropriate values for your remote machine.

## Script Descriptions

1. `install.sh`: Main installation script that sets up the environment on a remote machine.
2. `create_ubuntu_qcow.sh`: Creates an Ubuntu QCOW2 image with cloud-init configuration.
3. `create_vm_from_qcow.sh`: Creates a VM from the QCOW2 image with customizable options.
4. `create_tap.sh`: Creates a TAP interface for networking with customizable options.
5. `iptables.sh`: Sets up iptables rules for network connectivity with configurable interfaces.
6. `clear_cloud_config.sh`: Cleans up cloud-init artifacts from the image, with options for mount path and image location.
7. `get_ip_of_machine.sh`: Retrieves the IP address of a VM with a configurable number of attempts.
8. `wait_for_login.sh`: Waits for the VM to become accessible via SSH, with customizable timeout and interval.
9. `remove_test_files.sh`: Removes temporary files created during the process.
10. `setup_dnsmasq.sh`: Sets up dnsmasq for DHCP and DNS services with customizable IP ranges.

## Prerequisites

- Minimega installed on the remote machine
- SSH access to the remote machine
- Sufficient permissions to run scripts with sudo
- `cloud-image-utils` package (installed by the script if not present)
- `jq` command-line JSON processor (used in some scripts)

## Usage

1. Clone this repository to your local machine.
2. Ensure that the scripts have execute permissions:
   ```bash
   chmod +x *.sh
   ```
3. Run the `install.sh` script with appropriate parameters:
   ```bash
   ./install.sh <username> <hostname> <password_file>
   ```

This will set up the environment on the remote machine, create the QCOW2 image, and launch a VM.

## Customization

You can modify or use command-line options for the following scripts to customize the setup:

- `create_ubuntu_qcow.sh`: Adjust VM specifications (memory, CPUs) or cloud-init configuration.
- `create_vm_from_qcow.sh`: Modify VM settings for the final VM. Use `-h` or `--help` to see available options.
- `create_tap.sh`: Customize TAP interface name and IP address using `-t` or `--tap` and `-i` or `--ip` options.
- `iptables.sh`: Customize network settings and firewall rules by specifying WAN and INTERNAL interfaces as arguments.
- `clear_cloud_config.sh`: Customize mount path and disk image location using `-m` or `--mount-path` and `-i` or `--image` options.
- `setup_dnsmasq.sh`: Customize IP ranges for DHCP using `-s` or `--start-ip`, `-r` or `--range-start`, and `-e` or `--range-end` options.

## Troubleshooting

- If you encounter network issues, check the output of `iptables.sh` for connectivity test results.
- Use `get_ip_of_machine.sh` to retrieve the IP address of a VM if needed.
- The `wait_for_login.sh` script can be used to verify when a VM is ready for SSH access. It includes a configurable number of attempts and sleep interval.
- If you're having issues with DNS or DHCP, check the configuration of `setup_dnsmasq.sh`.

## Cleanup

To remove temporary files created during the process, run:

```bash
./remove_test_files.sh
```

## Note

This project assumes you have Minimega installed and properly configured on the remote machine. Make sure you have the necessary permissions and that Minimega is running before using these scripts.

## Security Considerations

- The scripts use SSH key-based authentication for increased security.
- Ensure that the `password_file` used with `install.sh` is stored securely and deleted after use.
- Review and adjust the iptables rules in `iptables.sh` to match your security requirements.
- When using `setup_dnsmasq.sh`, ensure that the IP ranges are appropriate for your network and don't conflict with existing DHCP servers.

## Troubleshooting

If you encounter issues:
1. Check Minimega logs for any errors.
2. Ensure all prerequisites are installed and up-to-date.
3. Verify network settings and firewall rules.
4. Use the `--help` option with scripts that support it for usage information.
5. If you're having DHCP or DNS issues, check the dnsmasq configuration set by `setup_dnsmasq.sh`.
