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

echo "Installing ansible"
ssh -o StrictHostKeyChecking=no $user@$hostname 'sudo apt-get update && sudo apt-get -y install ansible python3-pip python3.10-venv git && sudo locale-gen en_US.UTF-8 && sudo update-locale'

echo "Checking out code"
ssh -o StrictHostKeyChecking=no $user@$hostname "cd ~ && rm -rf LME && git clone https://github.com/cisagov/LME.git && cd LME && git checkout -t origin/${branch}"
echo "Code cloned to $HOME/LME"

echo "Setting config file"
ssh -o StrictHostKeyChecking=no $user@$hostname << EOF
    cd ~/LME
    cp config/example.env config/lme-environment.env
    . testing/v2/installers/lib/capture_ip.sh
    ./testing/v2/installers/lib/replace_home_in_config.sh
EOF

echo "Running ansible installer"
ssh -o StrictHostKeyChecking=no $user@$hostname "cd ~/LME && ansible-playbook ansible/install_lme_local.yml"

echo "Waiting for Kibana and Elasticsearch to start..."

# Wait for services to start
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if ssh -o StrictHostKeyChecking=no $user@$hostname bash << EOF
        # Source the environment file as root to get necessary variables
        sudo bash << SUDO_EOF
            set -a
            source /opt/lme/lme-environment.env
            echo "export IPVAR=\\\${IPVAR}" > /tmp/lme_env
            echo "export LOCAL_KBN_URL=\\\${LOCAL_KBN_URL}" >> /tmp/lme_env
            set +a
SUDO_EOF
        
        # Read the exported variables
        set -a
        . /tmp/lme_env
        echo "Exported variables:"
        cat /tmp/lme_env
        
        # Source the secrets
        . ~/LME/scripts/extract_secrets.sh -q

        check_service() {
            local url=\$1
            local auth=\$2
            curl -k -s -o /dev/null -w '%{http_code}' --insecure -u "\${auth}" "\${url}" | grep -q '200'
        }
        check_service "https://\${IPVAR}:9200" "elastic:\${elastic}" && \
        check_service "\${LOCAL_KBN_URL}" "elastic:\${elastic}"
EOF
    then
        echo "Both Elasticsearch and Kibana are up!"
        break
    fi
    attempt=$((attempt+1))
    echo "Attempt $attempt/$max_attempts: Services not ready yet. Waiting 10 seconds..."
    sleep 10
done

if [ $attempt -eq $max_attempts ]; then
    echo "Timeout: Services did not start within the expected time."
    exit 1
fi

echo "Running check-fleet script"
ssh -o StrictHostKeyChecking=no $user@$hostname "sudo -E bash -c 'source /opt/lme/lme-environment.env && su $user -c \". ~/.bashrc && cd ~/LME && ./testing/v2/installers/lib/check_fleet.sh\"'"

#echo "Running set-fleet script"
#ssh -o StrictHostKeyChecking=no $user@$hostname "sudo -E bash -c 'cd ~/LME/ansible && ansible-playbook set_fleet.yml -e \"debug_mode=true\"'"

echo "Running post install script"
ssh -o StrictHostKeyChecking=no $user@$hostname "sudo -E bash -c 'cd ~/LME/ansible && ansible-playbook post_install_local.yml -e \"debug_mode=true\"'"

echo "Installation and configuration completed successfully."

# Change back to the original directory
cd "$ORIGINAL_DIR"