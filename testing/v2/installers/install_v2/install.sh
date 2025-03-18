#!/bin/bash

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

echo "Checking ubuntu version"
ssh -o StrictHostKeyChecking=no $user@$hostname 'cat /etc/os-release'

echo "Updating apt"
ssh -o StrictHostKeyChecking=no $user@$hostname 'sudo rm -rf /var/lib/apt/lists/* && sudo mkdir -p /var/lib/apt/lists/partial && sudo apt-get clean && sudo apt-get update'

echo "Checking ansible and python version"
ssh -o StrictHostKeyChecking=no $user@$hostname 'apt-cache policy ansible python3-pip python3-venv'


echo "Installing ansible"
ssh -o StrictHostKeyChecking=no $user@$hostname '
echo "Adding universe repository..."
sudo add-apt-repository -y universe
echo "Updating package lists..."
sudo apt-get update
echo "Installing required packages..."
sudo DEBIAN_FRONTEND=noninteractive apt-get -V -y install python3-pip python3-venv git
echo "Generating locale..."
sudo locale-gen en_US.UTF-8
echo "Updating locale..."
sudo update-locale
'

echo "Checking out code"
ssh -o StrictHostKeyChecking=no $user@$hostname "cd ~ && rm -rf LME && git clone https://github.com/cisagov/LME.git"
if [ "${branch}" != "main" ]; then
    ssh -o StrictHostKeyChecking=no $user@$hostname "cd ~/LME && git checkout -t origin/${branch}"
fi
echo "Code cloned to $HOME/LME"

echo "Running LME installer"
ssh -o StrictHostKeyChecking=no $user@$hostname "export NON_INTERACTIVE=true && export AUTO_CREATE_ENV=true && export AUTO_IP=10.1.0.5 && cd ~/LME && ./install.sh"

echo "Installation and configuration completed successfully."

# Change back to the original directory
cd "$ORIGINAL_DIR"