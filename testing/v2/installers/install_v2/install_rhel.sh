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

echo "Checking OS version"
ssh -o StrictHostKeyChecking=no $user@$hostname 'cat /etc/os-release'

echo "Updating apt"
ssh -o StrictHostKeyChecking=no $user@$hostname 'sudo dnf -y install git'

echo "Checking out code"
ssh -o StrictHostKeyChecking=no $user@$hostname "cd ~ && rm -rf LME && git clone https://github.com/cisagov/LME.git"
if [ "${branch}" != "main" ]; then
    ssh -o StrictHostKeyChecking=no $user@$hostname "
        cd ~/LME && 
        git fetch --all --tags && 
        if git show-ref --tags --verify --quiet \"refs/tags/${branch}\"; then
            echo \"Checking out tag: ${branch}\"
            git checkout ${branch}
        else
            echo \"Checking out branch: ${branch}\"
            git checkout -t origin/${branch}
        fi
    "
fi
echo "Code cloned to $HOME/LME"

echo "Expanding disks"
ssh -o StrictHostKeyChecking=no $user@$hostname "cd ~/LME && sudo ./scripts/expand_rhel_disk.sh --yes"

echo "Running LME installer"
ssh -o StrictHostKeyChecking=no $user@$hostname "export NON_INTERACTIVE=true && export AUTO_CREATE_ENV=true && export AUTO_IP=10.1.0.5 && cd ~/LME && ./install.sh --debug"

echo "Installation and configuration completed successfully."

# Change back to the original directory
cd "$ORIGINAL_DIR"