#!/bin/bash

# Upgrade-to-Cluster Test Script
# Run from: testing/v2/installers/cluster_installer
#
# This script:
#   1. Provisions 3 Ubuntu VMs in Azure
#   2. Installs regular single-node LME on the master
#   3. Upgrades the installation to a multi-node cluster via convert_to_cluster.sh
#
# This tests the upgrade path rather than a direct cluster install.

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default options
DEBUG_MODE="false"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--debug)
            DEBUG_MODE="true"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "OPTIONS:"
            echo "  -d, --debug    Enable debug mode for verbose ansible output"
            echo "  -h, --help     Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Function to wait for SSH to be ready on a host
wait_for_ssh() {
    local host=$1
    local user=$2
    local password=$3
    local max_attempts=30
    local attempt=1

    echo -n "    Waiting for SSH on $host "
    while [ $attempt -le $max_attempts ]; do
        if sshpass -p "$password" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=no "${user}@${host}" "echo ok" &>/dev/null; then
            echo -e " ${GREEN}ready${NC}"
            return 0
        fi
        echo -n "."
        sleep 10
        ((attempt++))
    done
    echo -e " ${RED}timeout${NC}"
    return 1
}

# Function to wait for network connectivity on a remote host
wait_for_network() {
    local ssh_target=$1
    local test_host=${2:-"github.com"}
    local max_attempts=30
    local attempt=1

    echo -n "    Waiting for network connectivity to $test_host "
    while [ $attempt -le $max_attempts ]; do
        if ssh "$ssh_target" "curl -s --connect-timeout 5 https://${test_host} >/dev/null 2>&1"; then
            echo -e " ${GREEN}ready${NC}"
            return 0
        fi
        echo -n "."
        sleep 10
        ((attempt++))
    done
    echo -e " ${RED}timeout${NC}"
    return 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLERS_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${GREEN}=== LME Upgrade-to-Cluster Test ===${NC}"
echo "Script directory: $SCRIPT_DIR"
echo "Installers directory: $INSTALLERS_DIR"
if [ "$DEBUG_MODE" = "true" ]; then
    echo -e "${YELLOW}Debug mode: ENABLED${NC}"
fi

# Change to installers directory
cd "$INSTALLERS_DIR"
echo -e "${GREEN}Changed to: $(pwd)${NC}"

# Check for exporter.txt
if [ ! -f "exporter.txt" ]; then
    echo -e "${RED}Error: exporter.txt not found in $INSTALLERS_DIR${NC}"
    echo -e "${YELLOW}Create exporter.txt with the following variables:${NC}"
    cat << 'EOF'
export RESOURCE_GROUP="LME-yourname-rg"
export PUBLIC_IP="YOUR_IP/32"
export VM_SIZE="Standard_E2d_v4"
export LOCATION="westus"
export AUTO_SHUTDOWN_TIME="00:00"
export LME_USER="lme-user"
export BRANCH="your-branch-name"
EOF
    exit 1
fi

# Source environment variables
echo -e "${YELLOW}Sourcing exporter.txt...${NC}"
source exporter.txt

# Validate required variables
REQUIRED_VARS=("RESOURCE_GROUP" "PUBLIC_IP" "LME_USER" "BRANCH")
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        echo -e "${RED}Error: $var is not set in exporter.txt${NC}"
        exit 1
    fi
done

echo -e "${GREEN}Environment variables loaded:${NC}"
echo "  RESOURCE_GROUP: $RESOURCE_GROUP"
echo "  PUBLIC_IP: $PUBLIC_IP"
echo "  VM_SIZE: ${VM_SIZE:-Standard_E2d_v4}"
echo "  LOCATION: ${LOCATION:-westus}"
echo "  LME_USER: $LME_USER"
echo "  BRANCH: $BRANCH"

# Set defaults if not provided
VM_SIZE="${VM_SIZE:-Standard_E2d_v4}"
LOCATION="${LOCATION:-westus}"
AUTO_SHUTDOWN_TIME="${AUTO_SHUTDOWN_TIME:-00:00}"
CLUSTER_SIZE="${CLUSTER_SIZE:-3}"

# Build ansible options based on debug mode
ANSIBLE_OPTS=""
if [ "$DEBUG_MODE" = "true" ]; then
    ANSIBLE_OPTS="-e debug_mode=true -vvvv"
    echo -e "${YELLOW}Ansible debug options: $ANSIBLE_OPTS${NC}"
fi

# Setup Python venv
echo -e "${YELLOW}Setting up Python virtual environment...${NC}"
VENV_NEEDS_RECREATE=false

if [ -d "venv" ]; then
    if [ -f "venv/bin/activate" ] && [ -f "venv/bin/python3" ]; then
        source venv/bin/activate
        VENV_PYTHON=$(which python3)
        if [[ "$VENV_PYTHON" == *"venv"* ]]; then
            echo -e "${GREEN}Using existing venv: $VENV_PYTHON${NC}"
            VENV_NEEDS_RECREATE=false
        else
            echo -e "${YELLOW}Existing venv appears broken, will recreate...${NC}"
            deactivate 2>/dev/null || true
            VENV_NEEDS_RECREATE=true
        fi
    else
        echo -e "${YELLOW}Existing venv is incomplete, will recreate...${NC}"
        VENV_NEEDS_RECREATE=true
    fi
else
    VENV_NEEDS_RECREATE=true
fi

if [ "$VENV_NEEDS_RECREATE" = "true" ]; then
    if [ -d "venv" ]; then
        echo "Removing broken/incomplete venv..."
        rm -rf venv
    fi
    echo "Creating new venv..."
    python3 -m venv venv

    if [ ! -f "venv/bin/activate" ]; then
        echo -e "${RED}Error: Failed to create virtual environment${NC}"
        exit 1
    fi

    source venv/bin/activate

    VENV_PYTHON=$(which python3)
    if [[ "$VENV_PYTHON" != *"venv"* ]]; then
        echo -e "${RED}Error: Virtual environment activation failed${NC}"
        echo "Expected venv python, got: $VENV_PYTHON"
        exit 1
    fi

    echo -e "${GREEN}Created and activated venv: $VENV_PYTHON${NC}"
fi

# Install Azure requirements
echo -e "${YELLOW}Installing Azure requirements...${NC}"
pip install -q -r azure/requirements.txt
echo -e "${GREEN}Requirements installed${NC}"

# Check for required local tools
echo -e "${YELLOW}Checking for required tools...${NC}"
for tool in jq sshpass; do
    if ! command -v $tool &> /dev/null; then
        echo -e "${RED}Error: $tool is not installed${NC}"
        echo -e "${YELLOW}Install with: sudo apt-get install -y $tool${NC}"
        exit 1
    fi
done
echo -e "${GREEN}All required tools found${NC}"

# Build the VMs
echo -e "${YELLOW}Building $CLUSTER_SIZE Ubuntu VMs...${NC}"
./azure/build_azure_linux_network.py \
    -g "$RESOURCE_GROUP" \
    -s "$PUBLIC_IP" \
    -vs "$VM_SIZE" \
    -l "$LOCATION" \
    -ast "$AUTO_SHUTDOWN_TIME" \
    -c "$CLUSTER_SIZE" \
    -y

# Set variables from generated files
echo -e "${YELLOW}Loading generated credentials...${NC}"
PASSWORD=$(cat "${RESOURCE_GROUP}.password.txt")
MASTER_IP=$(jq -r '.linux_vms[0].ip_address' "${RESOURCE_GROUP}.machines.json")

# Copy generated files to output directory for persistence
OUTPUT_DIR="${SCRIPT_DIR}/output"
if [ -d "$OUTPUT_DIR" ] || mkdir -p "$OUTPUT_DIR" 2>/dev/null; then
    cp "${RESOURCE_GROUP}.password.txt" "$OUTPUT_DIR/"
    cp "${RESOURCE_GROUP}.machines.json" "$OUTPUT_DIR/"
    echo -e "${GREEN}Saved credentials to output directory:${NC}"
    echo "  - $OUTPUT_DIR/${RESOURCE_GROUP}.password.txt"
    echo "  - $OUTPUT_DIR/${RESOURCE_GROUP}.machines.json"
fi

echo -e "${GREEN}VMs created:${NC}"
echo "  Master IP: $MASTER_IP"
echo "  Password: $PASSWORD"
jq -r '.linux_vms[] | "  \(.vm_name): \(.ip_address) (private: \(.private_ip))"' "${RESOURCE_GROUP}.machines.json"

# Wait for VMs to fully boot before checking SSH
echo -e "${YELLOW}Waiting 2 minutes for VMs to fully boot...${NC}"
sleep 120

# Wait for SSH to be ready on all machines
echo -e "${YELLOW}Waiting for SSH to be ready on all machines...${NC}"
for IP in $(jq -r '.linux_vms[].ip_address' "${RESOURCE_GROUP}.machines.json"); do
    wait_for_ssh "$IP" "$LME_USER" "$PASSWORD"
done

# Generate an SSH key non-interactively if it doesn't exist
SSH_KEY_PATH="$HOME/.ssh/id_rsa"
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo -e "${YELLOW}Generating SSH key...${NC}"
    ssh-keygen -t rsa -N "" -f "$SSH_KEY_PATH" <<< y >/dev/null 2>&1
    echo -e "${GREEN}SSH key generated${NC}"
fi

# Copy SSH keys to all machines
echo -e "${YELLOW}Copying SSH keys to all machines...${NC}"
for IP in $(jq -r '.linux_vms[].ip_address' "${RESOURCE_GROUP}.machines.json"); do
    echo "  Copying key to $IP..."
    if sshpass -p "$PASSWORD" ssh-copy-id -o StrictHostKeyChecking=no "${LME_USER}@${IP}"; then
        echo -e "    ${GREEN}Done${NC}"
    else
        echo -e "    ${RED}Failed${NC}"
        exit 1
    fi
done
echo -e "${GREEN}SSH keys copied to all machines${NC}"

# Get list of private IPs for cluster nodes (excluding master)
CLUSTER_PRIVATE_IPS=$(jq -r '.linux_vms[1:][].private_ip' "${RESOURCE_GROUP}.machines.json")

echo ""
echo -e "${GREEN}=== Local setup complete ===${NC}"
echo ""

# Generate SSH key on master
echo -e "${YELLOW}Generating SSH key on master...${NC}"
ssh "${LME_USER}@${MASTER_IP}" "ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/id_rsa -q <<< y 2>/dev/null || true"
echo -e "${GREEN}SSH key generated on master${NC}"

# Install sshpass on master first (needed for copying keys)
echo -e "${YELLOW}Installing sshpass on master...${NC}"
ssh "${LME_USER}@${MASTER_IP}" "sudo apt-get update && sudo apt-get install -y sshpass"
echo -e "${GREEN}sshpass installed on master${NC}"

# Copy master's key to cluster nodes using sshpass
echo -e "${YELLOW}Copying master's SSH key to cluster nodes...${NC}"
for ip in $CLUSTER_PRIVATE_IPS; do
    echo "  Copying key to $ip..."
    if ssh "${LME_USER}@${MASTER_IP}" "sshpass -p '$PASSWORD' ssh-copy-id -o StrictHostKeyChecking=no ${LME_USER}@${ip}"; then
        echo -e "    ${GREEN}Done${NC}"
    else
        echo -e "    ${RED}Failed${NC}"
        exit 1
    fi
done
echo -e "${GREEN}Master SSH key copied to all cluster nodes${NC}"

# Test SSH connectivity from master to cluster nodes
echo -e "${YELLOW}Testing SSH connectivity from master to cluster nodes...${NC}"
for ip in $CLUSTER_PRIVATE_IPS; do
    HOSTNAME=$(ssh "${LME_USER}@${MASTER_IP}" "ssh -o StrictHostKeyChecking=no ${LME_USER}@${ip} hostname")
    echo "  $ip -> $HOSTNAME"
done
echo -e "${GREEN}SSH connectivity verified${NC}"

# Wait for network connectivity before cloning
echo -e "${YELLOW}Checking network connectivity on master...${NC}"
wait_for_network "${LME_USER}@${MASTER_IP}" "github.com"

# Clone repo and checkout branch on master
echo -e "${YELLOW}Cloning LME repo on master...${NC}"
ssh "${LME_USER}@${MASTER_IP}" "git clone https://github.com/cisagov/LME.git ~/LME"
ssh "${LME_USER}@${MASTER_IP}" "cd ~/LME && git checkout ${BRANCH}"
echo -e "${GREEN}Repo cloned and checked out to ${BRANCH}${NC}"

# Create lme-environment.env file with master's private IP
echo -e "${YELLOW}Creating lme-environment.env on master...${NC}"
MASTER_PRIVATE_IP=$(jq -r '.linux_vms[0].private_ip' "${RESOURCE_GROUP}.machines.json")
ssh "${LME_USER}@${MASTER_IP}" "cp ~/LME/config/example.env ~/LME/config/lme-environment.env"
ssh "${LME_USER}@${MASTER_IP}" "sed -i 's/IPVAR=.*/IPVAR=${MASTER_PRIVATE_IP}/' ~/LME/config/lme-environment.env"
echo -e "${GREEN}Environment file created with IPVAR=${MASTER_PRIVATE_IP}${NC}"

# Install jq on master (needed for inventory generation; install.sh handles ansible)
echo -e "${YELLOW}Installing jq on master...${NC}"
ssh "${LME_USER}@${MASTER_IP}" "sudo apt-get install -y jq"
echo -e "${GREEN}jq installed on master${NC}"

###############################################################################
# Phase 1: Single-node LME install via install.sh (non-interactive)
###############################################################################
echo ""
echo -e "${GREEN}=== Phase 1: Single-node LME install ===${NC}"
echo ""

echo -e "${YELLOW}Running single-node LME install on master via install.sh (this may take a while)...${NC}"
# install.sh may return non-zero if optional steps like fleet/kibana setup time out,
# even when the core Elasticsearch install succeeded. We check ES health instead of
# relying solely on the exit code.
ssh "${LME_USER}@${MASTER_IP}" "cd ~/LME && NON_INTERACTIVE=true bash install.sh${DEBUG_MODE:+ -d}" || true

echo -e "${YELLOW}Verifying Elasticsearch is healthy before proceeding...${NC}"
ES_HEALTHY=false
for i in $(seq 1 12); do
    STATUS=$(ssh "${LME_USER}@${MASTER_IP}" "sudo bash -c 'source /opt/lme/scripts/extract_secrets.sh -q && curl -sk -u \"elastic:\$elastic\" https://localhost:9200/_cluster/health'" 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status',''))" 2>/dev/null || true)
    if [[ "$STATUS" == "green" || "$STATUS" == "yellow" ]]; then
        echo -e "${GREEN}Elasticsearch is $STATUS - proceeding${NC}"
        ES_HEALTHY=true
        break
    fi
    echo "  Attempt $i/12: ES not ready yet (status: ${STATUS:-unreachable}), waiting 30s..."
    sleep 30
done

if [ "$ES_HEALTHY" != "true" ]; then
    echo -e "${RED}Error: Elasticsearch is not healthy after install. Cannot proceed with upgrade.${NC}"
    exit 1
fi
echo -e "${GREEN}Single-node install complete${NC}"

###############################################################################
# Phase 2: Prepare cluster inventory and run upgrade
###############################################################################
echo ""
echo -e "${GREEN}=== Phase 2: Upgrade to cluster ===${NC}"
echo ""

# Create cluster inventory file and scp to master
# IMPORTANT: Master (es1) must be first in the elasticsearch group so that
# the certs role generates certs on es1 and distributes to all cluster nodes.
echo -e "${YELLOW}Creating cluster inventory file...${NC}"
INVENTORY_FILE=$(mktemp)

# Build the seed hosts YAML list
SEED_HOSTS_YAML=""
for ip in $(jq -r '.linux_vms[].private_ip' "${RESOURCE_GROUP}.machines.json"); do
    SEED_HOSTS_YAML="${SEED_HOSTS_YAML}      - ${ip}\n"
done

cat > "$INVENTORY_FILE" << EOF
all:
  vars:
    # Master node IP for cluster discovery
    es_master_host: ${MASTER_PRIVATE_IP}
    # All seed hosts for cluster discovery
    es_cluster_seed_hosts:
$(echo -e "$SEED_HOSTS_YAML")
  children:
    elasticsearch:
      hosts:
        # es1 (master) must be first for cert generation
        es1:
          ansible_host: ${MASTER_PRIVATE_IP}
          ansible_connection: local
          es_node_name: lme-elasticsearch
          es_is_initial_master: true
          es_publish_host: ${MASTER_PRIVATE_IP}
EOF

i=2
for ip in $CLUSTER_PRIVATE_IPS; do
    cat >> "$INVENTORY_FILE" << EOF
        es${i}:
          ansible_host: ${ip}
          ansible_user: ${LME_USER}
          es_node_name: es${i}
          es_publish_host: ${ip}
EOF
    ((i++))
done

scp "$INVENTORY_FILE" "${LME_USER}@${MASTER_IP}:~/LME/ansible/inventory/cluster.yml"
rm "$INVENTORY_FILE"
echo -e "${GREEN}Cluster inventory created${NC}"

# Show inventory file
echo -e "${YELLOW}Inventory file contents:${NC}"
ssh "${LME_USER}@${MASTER_IP}" "cat ~/LME/ansible/inventory/cluster.yml"

# Run the upgrade from single-node to cluster
echo -e "${YELLOW}Running upgrade to cluster (this may take a while)...${NC}"
ssh "${LME_USER}@${MASTER_IP}" "cd ~/LME && bash scripts/convert_to_cluster.sh --skip-inventory --skip-prompts"
echo -e "${GREEN}Upgrade to cluster complete${NC}"

echo ""
echo -e "${GREEN}=== Upgrade test complete ===${NC}"
echo ""
echo "Master: ${LME_USER}@${MASTER_IP}"
echo ""
echo -e "${YELLOW}To SSH to master:${NC}"
echo -e "   ${GREEN}ssh ${LME_USER}@${MASTER_IP}${NC}"
echo ""
echo -e "${YELLOW}To check cluster health:${NC}"
echo -e "   ${GREEN}ssh ${LME_USER}@${MASTER_IP} 'sudo bash -c \"source /opt/lme/scripts/extract_secrets.sh -q && curl -sk -u \\\"elastic:\\\$elastic\\\" https://localhost:9200/_cluster/health?pretty\"'${NC}"
echo ""
echo -e "${YELLOW}To see cluster nodes:${NC}"
echo -e "   ${GREEN}ssh ${LME_USER}@${MASTER_IP} 'sudo bash -c \"source /opt/lme/scripts/extract_secrets.sh -q && curl -sk -u \\\"elastic:\\\$elastic\\\" https://localhost:9200/_cat/nodes?v\"'${NC}"
echo ""
echo -e "${YELLOW}Cleanup when done:${NC}"
echo -e "   ${GREEN}az group delete --name $RESOURCE_GROUP --yes --no-wait${NC}"
