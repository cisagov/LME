#!/usr/bin/env bash
set -e

# Function to print usage
print_usage() {
    echo "Usage: $0 <username> <hostname> <password_file>"
    echo "Required parameters:"
    echo "  <username>: The username for the remote server"
    echo "  <hostname>: The hostname or IP address of the remote server"
    echo "  <password_file>: The file containing the password for the remote server"
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

# Store the original working directory
ORIGINAL_DIR="$(pwd)"

# Get the directory of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# TODO: Need to set up the env file and source it for other scripts
cd "$SCRIPT_DIR"
cp .env.example .env

# Change to the parent directory of the script
cd "$SCRIPT_DIR/.."

# Copy the SSH key to the remote machine
./lib/copy_ssh_key.sh $user $hostname $password_file

# Copy the windows qcow directory to the remote machine
scp -r ./windows_qcow $user@$hostname:/home/$user

# Copy the ubuntu qcow maker directory to the remote machine
scp -r ./ubuntu_qcow_maker $user@$hostname:/home/$user

# Run the install_local.sh script on the remote machine
ssh $user@$hostname "cd /home/$user/windows_qcow && sudo ./install_local.sh"

# Change back to the original directory
cd "$ORIGINAL_DIR"
