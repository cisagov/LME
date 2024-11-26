#!/usr/bin/env bash
#!/usr/bin/env bash
set -e

# Function to print usage
print_usage() {
    echo "Usage: $0 <username> <hostname> <password_file> [num_cpus] [memory_mb]"
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

echo "$SCRIPT_DIR"

# Copy the SSH key to the remote machine
./lib/copy_ssh_key.sh $user $hostname $password_file

cp "windows_qcow/.env.example" "windows_qcow/.env"

if [[ ! -z "$AZURE_CLIENT_ID" ]] && [[ ! -z "$AZURE_CLIENT_SECRET" ]] && [[ ! -z "$AZURE_TENANT_ID" ]]; then
    echo "AZURE_CLIENT_ID: $AZURE_CLIENT_ID" >> "windows_qcow/.env"
    echo "AZURE_CLIENT_SECRET: $AZURE_CLIENT_SECRET" >> "windows_qcow/.env"
    echo "AZURE_TENANT_ID: $AZURE_TENANT_ID" >> "windows_qcow/.env"
    echo "AZURE_SUBSCRIPTION_ID: $AZURE_SUBSCRIPTION_ID" >> "windows_qcow/.env"
fi

scp -r windows_qcow "ubuntu_qcow_maker" $user@$hostname:/home/$user

rm -rf windows_qcow/.env

ssh $user@$hostname "cd /home/${user}/windows_qcow && sudo ./install_local.sh"
