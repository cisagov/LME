#!/usr/bin/env bash
set -e

# Function to print usage
print_usage() {
    echo "Usage: $0 <username> <hostname> <password_file>"
    echo "All parameters are required:"
    echo "  <username>: The username for the remote server"
    echo "  <hostname>: The hostname or IP address of the remote server"
    echo "  <password_file>: The file containing the password for the remote server"
}

# Check if all required arguments are provided
if [ $# -ne 3 ]; then
    print_usage
    exit 1
fi

# Set the remote server details from the command-line arguments
user=$1
hostname=$2
password_file=$3

# Store the original working directory
ORIGINAL_DIR="$(pwd)"

# Get the directory of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Change to the parent directory of the script
cd "$SCRIPT_DIR/.."

# Copy the SSH key to the remote machine
./lib/copy_ssh_key.sh $user $hostname $password_file

# Copy the minimega directory to the remote machine
scp -r ./ubuntu_qcow_maker $user@$hostname:/home/$user

# Run the update_packages.sh script on the remote machine this reboots the machine
ssh $user@$hostname "cd /home/$user/ubuntu_qcow_maker && sudo ./create_ubuntu_qcow.sh"

# Create a tap interface on the remote machine
ssh $user@$hostname "cd /home/$user/ubuntu_qcow_maker && sudo ./create_tap.sh"

# Create a tap interface on the remote machine
ssh $user@$hostname "cd /home/$user/ubuntu_qcow_maker && sudo ./setup_dnsmasq.sh"

# Set up the iptables rules on the remote machine
ssh $user@$hostname "cd /home/$user/ubuntu_qcow_maker && sudo ./iptables.sh"

# Create the VM on the remote machine
ssh $user@$hostname "cd /home/$user/ubuntu_qcow_maker && sudo ./launch_multiple_vms.sh 2"

# Change back to the original directory
cd "$ORIGINAL_DIR"
