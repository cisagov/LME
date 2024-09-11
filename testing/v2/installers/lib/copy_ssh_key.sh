#!/usr/bin/env bash

# Check if the required arguments are provided
if [ $# -lt 3 ]; then
    echo "Usage: $0 <username> <hostname> <password_file>"
    exit 1
fi

# Check if sshpass is installed
if ! command -v sshpass &> /dev/null; then
    echo "Error: sshpass is not installed. Please install sshpass and try again."
    exit 1
fi

# Set the remote server details from the command-line arguments
user=$1
hostname=$2
password_file=$3

# Set the SSH key path
ssh_key_path="$HOME/.ssh/id_rsa"

# Generate an SSH key non-interactively if it doesn't exist
if [ ! -f "$ssh_key_path" ]; then
    ssh-keygen -t rsa -N "" -f "$ssh_key_path" <<<y >/dev/null 2>&1
    sleep 3
fi
echo password_file $password_file ssh_key_path $ssh_key_path
ls $password_file
ls $ssh_key_path
# Use sshpass with the password file to copy the SSH key to the remote server
sshpass -f "$password_file" ssh-copy-id -o StrictHostKeyChecking=no -i "$ssh_key_path.pub" $user@$hostname
