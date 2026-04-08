#!/bin/bash

# Cluster Installer Setup Script
# Run from: testing/v2/installers/cluster_installer
# This script sets up a multi-node LME cluster for testing

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default options
DEBUG_MODE="false"
SKIP_NFS="false"
NFS_ONLY="false"
RSYNC_LOCAL="false"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--debug)
            DEBUG_MODE="true"
            shift
            ;;
        --skip-nfs)
            SKIP_NFS="true"
            shift
            ;;
        --nfs-only)
            NFS_ONLY="true"
            shift
            ;;
        --rsync)
            RSYNC_LOCAL="true"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "OPTIONS:"
            echo "  -d, --debug    Enable debug mode for verbose ansible output"
            echo "  --skip-nfs     Skip NFS setup (master as NFS server, nodes as clients)"
            echo "  --nfs-only     Run only NFS setup (cluster must already be installed)"
            echo "  --rsync        Rsync local working tree to master after git checkout"
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

echo -e "${GREEN}=== LME Cluster Installer ===${NC}"
echo "Script directory: $SCRIPT_DIR"
echo "Installers directory: $INSTALLERS_DIR"
if [ "$DEBUG_MODE" = "true" ]; then
    echo -e "${YELLOW}Debug mode: ENABLED${NC}"
fi

# Change to installers directory
cd "$INSTALLERS_DIR"
echo -e "${GREEN}Changed to: $(pwd)${NC}"

if [ "$NFS_ONLY" = "true" ]; then
    echo -e "${YELLOW}NFS-only mode: skipping cluster build, will run NFS setup only${NC}"
fi

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

# Setup Python venv (skip when NFS-only)
if [ "$NFS_ONLY" != "true" ]; then
echo -e "${YELLOW}Setting up Python virtual environment...${NC}"
VENV_NEEDS_RECREATE=false

if [ -d "venv" ]; then
    # Check if existing venv is valid
    if [ -f "venv/bin/activate" ] && [ -f "venv/bin/python3" ]; then
        # Try to activate and verify it works
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

    # Verify venv was created correctly
    if [ ! -f "venv/bin/activate" ]; then
        echo -e "${RED}Error: Failed to create virtual environment${NC}"
        exit 1
    fi

    source venv/bin/activate

    # Verify activation worked
    VENV_PYTHON=$(which python3)
    if [[ "$VENV_PYTHON" != *"venv"* ]]; then
        echo -e "${RED}Error: Virtual environment activation failed${NC}"
        echo "Expected venv python, got: $VENV_PYTHON"
        exit 1
    fi

    echo -e "${GREEN}Created and activated venv: $VENV_PYTHON${NC}"
fi
fi

# Install Azure requirements (skip when NFS-only)
if [ "$NFS_ONLY" != "true" ]; then
echo -e "${YELLOW}Installing Azure requirements...${NC}"
pip install -q -r azure/requirements.txt
echo -e "${GREEN}Requirements installed${NC}"
fi

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

if [ "$NFS_ONLY" = "true" ]; then
    # Load from existing cluster files
    if [ ! -f "${RESOURCE_GROUP}.machines.json" ]; then
        if [ -f "${SCRIPT_DIR}/output/${RESOURCE_GROUP}.machines.json" ]; then
            cp "${SCRIPT_DIR}/output/${RESOURCE_GROUP}.machines.json" "${RESOURCE_GROUP}.machines.json"
        else
            echo -e "${RED}Error: ${RESOURCE_GROUP}.machines.json not found. Run full setup first or ensure cluster exists.${NC}"
            exit 1
        fi
    fi
    MASTER_IP=$(jq -r '.linux_vms[0].ip_address' "${RESOURCE_GROUP}.machines.json")
    MASTER_PRIVATE_IP=$(jq -r '.linux_vms[0].private_ip' "${RESOURCE_GROUP}.machines.json")
    echo -e "${GREEN}Using existing cluster: Master ${MASTER_IP} (private ${MASTER_PRIVATE_IP})${NC}"
else
# Build the cluster
echo -e "${YELLOW}Building cluster with $CLUSTER_SIZE nodes...${NC}"
./azure/build_azure_linux_network.py \
    -g "$RESOURCE_GROUP" \
    -s "$PUBLIC_IP" \
    -vs "$VM_SIZE" \
    -l "$LOCATION" \
    -ast "$AUTO_SHUTDOWN_TIME" \
    -c "$CLUSTER_SIZE" \
    -w \
    -y

# Set variables from generated files
echo -e "${YELLOW}Loading generated credentials...${NC}"
PASSWORD=$(cat "${RESOURCE_GROUP}.password.txt")
MASTER_IP=$(jq -r '.linux_vms[0].ip_address' "${RESOURCE_GROUP}.machines.json")

# Copy generated files to output directory for persistence
# When running in Docker, only the output directory is mounted from the host
OUTPUT_DIR="${SCRIPT_DIR}/output"
if [ -d "$OUTPUT_DIR" ] || mkdir -p "$OUTPUT_DIR" 2>/dev/null; then
    cp "${RESOURCE_GROUP}.password.txt" "$OUTPUT_DIR/"
    cp "${RESOURCE_GROUP}.machines.json" "$OUTPUT_DIR/"
    echo -e "${GREEN}Saved credentials to output directory:${NC}"
    echo "  - $OUTPUT_DIR/${RESOURCE_GROUP}.password.txt"
    echo "  - $OUTPUT_DIR/${RESOURCE_GROUP}.machines.json"
fi

echo -e "${GREEN}Cluster created:${NC}"
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

if [ "$RSYNC_LOCAL" = "true" ]; then
    echo -e "${YELLOW}Rsyncing local changes to master...${NC}"
    LOCAL_REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
    rsync -az --delete \
        --exclude='.git' \
        --exclude='venv' \
        --exclude='__pycache__' \
        --exclude='*.pyc' \
        --exclude='testing/v2/installers/venv' \
        "${LOCAL_REPO_ROOT}/" "${LME_USER}@${MASTER_IP}:~/LME/"
    echo -e "${GREEN}Local changes synced to master${NC}"
fi

# Create lme-environment.env file with master's private IP
echo -e "${YELLOW}Creating lme-environment.env on master...${NC}"
MASTER_PRIVATE_IP=$(jq -r '.linux_vms[0].private_ip' "${RESOURCE_GROUP}.machines.json")
ssh "${LME_USER}@${MASTER_IP}" "cp ~/LME/config/example.env ~/LME/config/lme-environment.env"
ssh "${LME_USER}@${MASTER_IP}" "sed -i 's/IPVAR=.*/IPVAR=${MASTER_PRIVATE_IP}/' ~/LME/config/lme-environment.env"
echo -e "${GREEN}Environment file created with IPVAR=${MASTER_PRIVATE_IP}${NC}"

# Install jq on master (install.sh handles ansible + ansible-galaxy)
echo -e "${YELLOW}Installing dependencies on master...${NC}"
ssh "${LME_USER}@${MASTER_IP}" "sudo apt-get install -y jq"
echo -e "${GREEN}Dependencies installed on master${NC}"

# Create cluster inventory file locally and scp to master BEFORE install.sh --cluster,
# which validates the inventory and derives seed hosts from it.
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

# Run cluster install via install.sh --cluster (handles ansible install, galaxy
# collections, inventory validation, site.yml on master, elasticsearch.yml on nodes)
echo -e "${YELLOW}Running install.sh --cluster on master (this may take a while)...${NC}"
INSTALL_FLAGS="--cluster"
if [ "$DEBUG_MODE" = "true" ]; then
    INSTALL_FLAGS="$INSTALL_FLAGS --debug"
fi
ssh "${LME_USER}@${MASTER_IP}" "cd ~/LME && NON_INTERACTIVE=true ./install.sh $INSTALL_FLAGS"
echo -e "${GREEN}Cluster install complete${NC}"

fi
# End of non-NFS-only block

# =========================================================================
# Phase 6: NFS setup (master = NFS server, all nodes mount shared snapshot storage)
# =========================================================================
if [ "$SKIP_NFS" = "true" ]; then
    echo -e "${YELLOW}Skipping NFS setup (--skip-nfs flag)${NC}"
else
    echo ""
    echo -e "${GREEN}Phase 6: NFS Setup (master as NFS server)${NC}"
    echo "================================================"

    # Build NFS exports line: allow each node's private IP
    NFS_EXPORTS="/srv/es-snapshots"
    for ip in $(jq -r '.linux_vms[].private_ip' "${RESOURCE_GROUP}.machines.json"); do
        NFS_EXPORTS="${NFS_EXPORTS} ${ip}(rw,sync,no_subtree_check,no_root_squash)"
    done

    # 6a: Set up NFS server on master
    echo -e "${YELLOW}Setting up NFS server on master...${NC}"
    ssh "${LME_USER}@${MASTER_IP}" "sudo apt-get install -y nfs-kernel-server"
    ssh "${LME_USER}@${MASTER_IP}" "sudo mkdir -p /srv/es-snapshots && sudo chmod 777 /srv/es-snapshots"
    ssh "${LME_USER}@${MASTER_IP}" "echo '${NFS_EXPORTS}' | sudo tee /etc/exports"
    ssh "${LME_USER}@${MASTER_IP}" "sudo exportfs -ra && sudo systemctl start nfs-kernel-server"
    echo -e "${GREEN}NFS server configured on master${NC}"

    # 6b: Mount snapshot storage on all nodes
    # Master gets a local bind mount (avoids NFS self-mount hangs);
    # data nodes get a real NFS client mount with explicit options.
    ALL_NODE_IPS=$(jq -r '.linux_vms[] | "\(.ip_address)|\(.private_ip)"' "${RESOURCE_GROUP}.machines.json")
    node_num=1
    for node_info in $ALL_NODE_IPS; do
        node_pub_ip="${node_info%%|*}"
        node_priv_ip="${node_info##*|}"

        if [ "$node_priv_ip" = "$MASTER_PRIVATE_IP" ]; then
            echo -e "${YELLOW}Bind-mounting /srv/es-snapshots on master (${node_pub_ip})...${NC}"
            ssh "${LME_USER}@${node_pub_ip}" "sudo mkdir -p /mnt/es-snapshots /srv/es-snapshots"
            ssh "${LME_USER}@${node_pub_ip}" "mountpoint -q /mnt/es-snapshots || sudo mount --bind /srv/es-snapshots /mnt/es-snapshots"
            ssh "${LME_USER}@${node_pub_ip}" "grep -q '/srv/es-snapshots /mnt/es-snapshots' /etc/fstab || echo '/srv/es-snapshots /mnt/es-snapshots none bind 0 0' | sudo tee -a /etc/fstab"
            echo -e "  ${GREEN}Bind mount on master${NC}"
            ((node_num++))
            continue
        fi

        echo -e "${YELLOW}Mounting NFS on node${node_num} (${node_pub_ip})...${NC}"
        ssh "${LME_USER}@${node_pub_ip}" "sudo apt-get install -y nfs-common"
        ssh "${LME_USER}@${node_pub_ip}" "sudo mkdir -p /mnt/es-snapshots"
        ssh "${LME_USER}@${node_pub_ip}" "sudo mount -t nfs -o vers=4.1,proto=tcp,hard,timeo=600,retrans=2 ${MASTER_PRIVATE_IP}:/srv/es-snapshots /mnt/es-snapshots"
        ssh "${LME_USER}@${node_pub_ip}" "grep -q '/mnt/es-snapshots' /etc/fstab || echo '${MASTER_PRIVATE_IP}:/srv/es-snapshots /mnt/es-snapshots nfs vers=4.1,proto=tcp,hard,timeo=600,retrans=2,_netdev,nofail 0 0' | sudo tee -a /etc/fstab"
        echo -e "  ${GREEN}NFS mounted on node${node_num}${NC}"
        ((node_num++))
    done

    # 6c: Configure ES on each node: add path.repo, Quadlet drop-in, restart
    echo -e "${YELLOW}Configuring Elasticsearch NFS snapshot path on all nodes...${NC}"
    node_num=1
    for node_info in $ALL_NODE_IPS; do
        node_pub_ip="${node_info%%|*}"
        echo "  Configuring node${node_num}..."
        ssh "${LME_USER}@${node_pub_ip}" "
            sudo grep -q '/usr/share/elasticsearch/snapshots' /opt/lme/config/elasticsearch.yml || \
                sudo sed -i '/\\/usr\\/share\\/elasticsearch\\/backups/a\\\\    - /usr/share/elasticsearch/snapshots' /opt/lme/config/elasticsearch.yml
        "
        ssh "${LME_USER}@${node_pub_ip}" "
            sudo mkdir -p /etc/containers/systemd/lme-elasticsearch.container.d/
            echo '[Container]
Volume=/mnt/es-snapshots:/usr/share/elasticsearch/snapshots' | sudo tee /etc/containers/systemd/lme-elasticsearch.container.d/nfs-mount.conf
        "
        ssh "${LME_USER}@${node_pub_ip}" "sudo systemctl daemon-reload && sudo systemctl restart lme-elasticsearch"
        ((node_num++))
    done
    echo -e "${GREEN}NFS setup complete on all nodes${NC}"
fi

echo ""
echo -e "${GREEN}=== Cluster setup complete ===${NC}"
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
