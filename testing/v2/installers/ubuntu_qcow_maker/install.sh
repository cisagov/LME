#!/usr/bin/env bash
set -e

# Function to print usage
print_usage() {
    echo "Usage: $0 <username> <hostname> <password_file> [num_cpus] [memory_mb]"
    echo "Required parameters:"
    echo "  <username>: The username for the remote server"
    echo "  <hostname>: The hostname or IP address of the remote server"
    echo "  <password_file>: The file containing the password for the remote server"
    echo "Optional parameters:"
    echo "  [num_cpus]: Number of CPUs for the VM (default: 2)"
    echo "  [memory_mb]: Amount of memory in MB for the VM (default: 2048)"
}

# Check if all required arguments are provided
if [ $# -lt 3 ]; then
    print_usage
    exit 1
fi

# Set the remote server details from the command-line arguments
user=$1
hostname=$2
password_file=$3

# Set default values for CPU and memory
num_cpus=${4:-2}
memory_mb=${5:-2048}

# Store the original working directory
ORIGINAL_DIR="$(pwd)"

# Get the directory of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Change to the parent directory of the script
cd "$SCRIPT_DIR/.."

# Copy the SSH key to the remote machine
./lib/copy_ssh_key.sh $user $hostname $password_file

# Copy the qcow maker directory to the remote machine
scp -r ./ubuntu_qcow_maker $user@$hostname:/home/$user

# Run the update_packages.sh script on the remote machine this reboots the machine
ssh $user@$hostname "cd /home/$user/ubuntu_qcow_maker && sudo ./create_ubuntu_qcow.sh"

# Create a tap interface on the remote machine
ssh $user@$hostname "cd /home/$user/ubuntu_qcow_maker && sudo ./create_tap.sh"

# Setup dnsmasq on the remote machine
ssh $user@$hostname "cd /home/$user/ubuntu_qcow_maker && sudo ./setup_dnsmasq.sh"

# Set up the iptables rules on the remote machine
ssh $user@$hostname "cd /home/$user/ubuntu_qcow_maker && sudo ./iptables.sh"

# Create the VM on the remote machine with the specified CPU and memory
ssh $user@$hostname "cd /home/$user/ubuntu_qcow_maker && sudo ./create_vm_from_qcow.sh -c $num_cpus -m $memory_mb"

# Change back to the original directory
cd "$ORIGINAL_DIR"
