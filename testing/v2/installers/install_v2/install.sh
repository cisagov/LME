#!/usr/bin/env bash

set -e

# Check if the required arguments are provided
if [ $# -lt 3 ]; then
    echo "Usage: $0 <username> <hostname> <password_file> <branch>"
    exit 1
fi

# Set the remote server details from the command-line arguments
user=$1
hostname=$2
password_file=$3
branch=$4

# Store the original working directory
ORIGINAL_DIR="$(pwd)"

# Get the directory of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Change to the parent directory of the script
cd "$SCRIPT_DIR/.."

# Copy the SSH key to the remote machine
./lib/copy_ssh_key.sh $user $hostname $password_file

echo "Installing ansible"
ssh  -o StrictHostKeyChecking=no $user@$hostname 'sudo apt-get update && sudo apt-get -y install ansible'


# Need to set up so we can checkout a particular branch or pull down a release
echo "Checking out code"
ssh  -o StrictHostKeyChecking=no $user@$hostname "cd ~ && rm -rf LME && git clone https://github.com/cisagov/LME.git && cd LME && git checkout -t origin/${branch}"
echo "Code cloned to $HOME/LME"

echo "Running ansible installer"
ssh  -o StrictHostKeyChecking=no $user@$hostname "cd ~/LME && cp config/example.env config/lme-environment.env && ansible-playbook scripts/install_lme_local.yml"

# Change back to the original directory
cd "$ORIGINAL_DIR"
