#!/usr/bin/env bash

set -e

# Check if the required arguments are provided
if [ $# -lt 3 ]; then
    echo "Usage: $0 <username> <hostname> <password_file>"
    exit 1
fi

# Set the remote server details from the command-line arguments
user=$1
hostname=$2
password_file=$3

# Copy the SSH key to the remote machine
./minimega/copy_ssh_key.sh $user $hostname $password_file

# Copy the minimega directory to the remote machine
scp -r ./ubuntu_qcow2_maker $user@$hostname:/home/$user

# Run the update_packages.sh script on the remote machine this reboots the machine
#ssh $user@$hostname "cd /home/$user/ubuntu_qcow2_maker && sudo ./create_ubuntu_machine.sh" 
