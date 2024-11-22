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

# Change to the parent directory of the script
cd "$SCRIPT_DIR/.."

# Copy the SSH key to the remote machine
./lib/copy_ssh_key.sh $user $hostname $password_file

# TODO: Need to set up the env file and source it for other scripts 
cp .env.example .env

# Copy the windows qcow directory to the remote machine
scp -r ./windows_qcow $user@$hostname:/home/$user

# Copy the ubuntu qcow maker directory to the remote machine
scp -r ./ubuntu_qcow_maker $user@$hostname:/home/$user

# Run the install_local.sh script on the remote machine
ssh $user@$hostname "cd /home/$user/windows_qcow && sudo ./install_local.sh"


#echo -e "\n>>>>>>>>>>>> Installing Azure"
#ssh $user@$hostname "cd /home/$user/windows_qcow && sudo ./install_azure.sh"
#
#echo -e "\n>>>>>>>>>>>> Getting Storage Key"
#ssh $user@$hostname "cd /home/$user/windows_qcow && sudo ./get_storage_key.sh"  
#
#echo -e "\n>>>>>>>>>>>> Downloading Blob File"
#ssh $user@$hostname "cd /home/$user/windows_qcow && sudo ./download_blob_file.sh"

#echo -e "\n>>>>>>>>>>>> Starting Networking ..."
#ssh $user@$hostname "cd /home/$user/windows_qcow && sudo ./start_networking.sh"
#
#echo -e "\n>>>>>>>>>>>> Starting Minimega ..."
#ssh $user@$hostname "sudo /opt/minimega/bin/minimega -e 'read /home/$user/windows_qcow/windows-runner.mm'"
#
#echo -e "\n>>>>>>>>>>>> Waiting for CC ..."
#ssh $user@$hostname "cd /home/$user/windows_qcow && sudo ./wait_for_cc.sh windows-runner"
#
#echo -e "\n>>>>>>>>>>>> Setting DNS ..."
#ssh $user@$hostname "cd /home/$user/windows_qcow && sudo ./set_dns.sh"  
#
#echo -e "\n>>>>>>>>>>>> Setting up SSH ..."
#ssh $user@$hostname "cd /home/$user/windows_qcow && sudo ./setup_ssh.sh"
#
#echo -e "\n>>>>>>>>>>>> Starting SSH Service ..."
#ssh $user@$hostname "cd /home/$user/windows_qcow && sudo ./start_ssh_service.sh"
#
#echo -e "\n>>>>>>>>>>>> Setting up RDP ..."
#ssh $user@$hostname "cd /home/$user/windows_qcow && sudo ./setup_rdp.sh"

# Change back to the original directory
cd "$ORIGINAL_DIR"
