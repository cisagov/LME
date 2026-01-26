#!/bin/bash

# LME Docker Cluster Install Script
# Run from the host machine while docker-compose-cluster.yml containers are running
# This script sets up SSH between containers and runs ansible to install the LME cluster

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Container names
MASTER_CONTAINER="lme_cluster_node1"
NODE2_CONTAINER="lme_cluster_node2"
NODE3_CONTAINER="lme_cluster_node3"

# Default options
DEBUG_MODE="false"
SKIP_MASTER_INSTALL="false"
SKIP_CLUSTER_INSTALL="false"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--debug)
            DEBUG_MODE="true"
            shift
            ;;
        --skip-master)
            SKIP_MASTER_INSTALL="true"
            shift
            ;;
        --skip-cluster)
            SKIP_CLUSTER_INSTALL="true"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "OPTIONS:"
            echo "  -d, --debug        Enable debug mode for verbose ansible output"
            echo "  --skip-master      Skip master installation (site.yml)"
            echo "  --skip-cluster     Skip cluster installation (elasticsearch.yml)"
            echo "  -h, --help         Show this help message"
            echo ""
            echo "Prerequisites:"
            echo "  - Docker containers must be running:"
            echo "    docker compose -f docker-compose-cluster.yml up -d --build"
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${GREEN}=== LME Docker Cluster Installer ===${NC}"
echo "Script directory: $SCRIPT_DIR"
if [ "$DEBUG_MODE" = "true" ]; then
    echo -e "${YELLOW}Debug mode: ENABLED${NC}"
fi

# Build ansible options based on debug mode
ANSIBLE_OPTS=""
if [ "$DEBUG_MODE" = "true" ]; then
    ANSIBLE_OPTS="-e debug_mode=true -v"
    echo -e "${YELLOW}Ansible debug options: $ANSIBLE_OPTS${NC}"
fi

# Function to run command in a container as root
docker_exec() {
    local container=$1
    shift
    docker exec "$container" bash -c "$*"
}

# Function to run command in a container as lme-user
docker_exec_as_lme_user() {
    local container=$1
    shift
    docker exec -u lme-user "$container" bash -c "$*"
}

# Function to check if containers are running
check_containers() {
    echo -e "${YELLOW}Checking if containers are running...${NC}"
    
    for container in "$MASTER_CONTAINER" "$NODE2_CONTAINER" "$NODE3_CONTAINER"; do
        if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            echo -e "${RED}Error: Container $container is not running${NC}"
            echo -e "${YELLOW}Start the cluster first:${NC}"
            echo -e "  cd $SCRIPT_DIR"
            echo -e "  docker compose -f docker-compose-cluster.yml up -d --build"
            exit 1
        fi
        echo -e "  ${GREEN}✓${NC} $container is running"
    done
}

# Function to install SSH server on a node
install_ssh_server() {
    local container=$1
    echo -e "${YELLOW}Installing SSH server on $container...${NC}"
    
    docker_exec "$container" "apt-get update && apt-get install -y openssh-server"
    # Set up SSH for lme-user (the user ansible will connect as)
    docker_exec "$container" "mkdir -p /home/lme-user/.ssh && chmod 700 /home/lme-user/.ssh && chown lme-user:lme-user /home/lme-user/.ssh"
    # Remove nologin file that blocks non-root users during boot
    docker_exec "$container" "rm -f /run/nologin /var/run/nologin /etc/nologin"
    docker_exec "$container" "service ssh start || /usr/sbin/sshd"
    
    echo -e "  ${GREEN}✓${NC} SSH server installed and started on $container"
}

# Function to generate SSH key on master for lme-user
generate_master_ssh_key() {
    echo -e "${YELLOW}Generating SSH key on master node for lme-user...${NC}"
    
    # Create .ssh directory for lme-user
    docker_exec "$MASTER_CONTAINER" "mkdir -p /home/lme-user/.ssh && chmod 700 /home/lme-user/.ssh && chown lme-user:lme-user /home/lme-user/.ssh"
    
    # Check if key already exists
    if docker_exec_as_lme_user "$MASTER_CONTAINER" "test -f ~/.ssh/id_rsa"; then
        echo -e "  ${GREEN}✓${NC} SSH key already exists on master"
    else
        docker_exec_as_lme_user "$MASTER_CONTAINER" "ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/id_rsa -q"
        echo -e "  ${GREEN}✓${NC} SSH key generated on master"
    fi
}

# Function to copy SSH key from master to a node
copy_ssh_key_to_node() {
    local node_container=$1
    local node_hostname=$2
    
    echo -e "${YELLOW}Copying SSH key from master to $node_hostname...${NC}"
    
    # Get master lme-user's public key
    local pubkey
    pubkey=$(docker_exec_as_lme_user "$MASTER_CONTAINER" "cat ~/.ssh/id_rsa.pub")
    
    # Add to lme-user's authorized_keys on the node
    docker_exec "$node_container" "echo '$pubkey' >> /home/lme-user/.ssh/authorized_keys"
    docker_exec "$node_container" "chmod 600 /home/lme-user/.ssh/authorized_keys"
    docker_exec "$node_container" "chown lme-user:lme-user /home/lme-user/.ssh/authorized_keys"
    
    # Add node to master lme-user's known_hosts
    docker_exec_as_lme_user "$MASTER_CONTAINER" "ssh-keyscan -H $node_hostname >> ~/.ssh/known_hosts 2>/dev/null || true"
    
    echo -e "  ${GREEN}✓${NC} SSH key copied to $node_hostname"
}

# Function to test SSH connectivity
test_ssh_connectivity() {
    local node_hostname=$1
    
    echo -e "${YELLOW}Testing SSH connectivity to $node_hostname...${NC}"
    
    # Test SSH from master as lme-user
    if docker_exec_as_lme_user "$MASTER_CONTAINER" "ssh -o StrictHostKeyChecking=no -o BatchMode=yes lme-user@$node_hostname hostname"; then
        echo -e "  ${GREEN}✓${NC} SSH connection to $node_hostname successful"
        return 0
    else
        echo -e "  ${RED}✗${NC} SSH connection to $node_hostname failed"
        return 1
    fi
}

# Function to create lme-environment.env
create_environment_file() {
    echo -e "${YELLOW}Creating lme-environment.env on master...${NC}"
    
    # Get master's IP address on the Docker network
    local master_ip
    master_ip=$(docker_exec "$MASTER_CONTAINER" "hostname -I | awk '{print \$1}'")
    
    echo -e "  Master IP: $master_ip"
    
    # Check if env file already exists (run as lme-user since LME is in their home dir)
    if docker_exec_as_lme_user "$MASTER_CONTAINER" "test -f ~/LME/config/lme-environment.env"; then
        echo -e "  ${YELLOW}lme-environment.env already exists, updating IPVAR...${NC}"
        docker_exec_as_lme_user "$MASTER_CONTAINER" "sed -i 's/IPVAR=.*/IPVAR=${master_ip}/' ~/LME/config/lme-environment.env"
    else
        docker_exec_as_lme_user "$MASTER_CONTAINER" "cp ~/LME/config/example.env ~/LME/config/lme-environment.env"
        docker_exec_as_lme_user "$MASTER_CONTAINER" "sed -i 's/IPVAR=.*/IPVAR=${master_ip}/' ~/LME/config/lme-environment.env"
    fi
    
    echo -e "  ${GREEN}✓${NC} Environment file created with IPVAR=${master_ip}"
}

# Function to install ansible and requirements
install_ansible() {
    echo -e "${YELLOW}Installing ansible and requirements on master...${NC}"
    
    # Install system packages as root
    docker_exec "$MASTER_CONTAINER" "apt-get update && apt-get install -y ansible jq"
    # Run galaxy install as lme-user (non-fatal - continue if galaxy is unavailable)
    echo -e "${YELLOW}Attempting ansible-galaxy install (may fail if Galaxy is unavailable)...${NC}"
    if docker_exec_as_lme_user "$MASTER_CONTAINER" "cd ~/LME/ansible && ansible-galaxy collection install -r requirements.yml --timeout 30" 2>&1; then
        echo -e "  ${GREEN}✓${NC} Galaxy collections installed"
    else
        echo -e "  ${YELLOW}⚠${NC} Galaxy install failed (server may be unavailable), continuing with existing collections..."
    fi
    
    echo -e "  ${GREEN}✓${NC} Ansible installed"
}

# Function to run site.yml on master
run_master_install() {
    echo -e "${YELLOW}Running main installation on master as lme-user (this may take a while)...${NC}"
    
    # Create Ansible temp directory (lme-user will use sudo for become operations)
    docker_exec "$MASTER_CONTAINER" "mkdir -p /tmp/ansible-tmp && chmod 777 /tmp/ansible-tmp"
    
    # Run ansible as lme-user - ansible will use become: yes to escalate to root
    # Enable cluster mode and set seed hosts for multi-node deployment
    # Pass seed hosts as JSON array and set publish host for master
    local cmd="cd ~/LME && ANSIBLE_LOCAL_TEMP=/tmp/ansible-tmp ANSIBLE_REMOTE_TEMP=/tmp/ansible-tmp ansible-playbook ansible/site.yml -e lme_cluster_mode=true -e '{\"es_cluster_seed_hosts\": [\"node1\", \"node2\", \"node3\"]}' -e es_master_publish_host=node1"
    if [ -n "$ANSIBLE_OPTS" ]; then
        cmd="$cmd $ANSIBLE_OPTS"
    fi
    
    docker_exec_as_lme_user "$MASTER_CONTAINER" "$cmd"
    
    echo -e "  ${GREEN}✓${NC} Main installation complete on master"
}

# Function to create cluster inventory
create_cluster_inventory() {
    echo -e "${YELLOW}Creating cluster inventory file...${NC}"
    
    # Create the inventory file - use sudo since ansible may have created root-owned files
    # Include cluster configuration variables for each node
    # IMPORTANT: Node1 (master) must be FIRST in the elasticsearch group so that
    # the certs role generates certs on node1 and distributes to all cluster nodes.
    # This ensures all nodes use the same CA and certificates.
    docker_exec_as_lme_user "$MASTER_CONTAINER" "sudo tee ~/LME/ansible/inventory/cluster.yml > /dev/null << 'EOF'
all:
  vars:
    # Master node hostname for cluster discovery
    es_master_host: node1
    # All seed hosts for cluster discovery
    es_cluster_seed_hosts:
      - node1
      - node2
      - node3
  children:
    elasticsearch:
      hosts:
        # es1 (node1) is the master and must be first for cert generation
        es1:
          ansible_host: node1
          ansible_connection: local
          es_node_name: lme-elasticsearch
          es_is_initial_master: true
          es_publish_host: node1
        es2:
          ansible_host: node2
          ansible_user: lme-user
          es_node_name: es2
          es_publish_host: node2
        es3:
          ansible_host: node3
          ansible_user: lme-user
          es_node_name: es3
          es_publish_host: node3
EOF"
    
    # Fix ownership so lme-user can read it
    docker_exec_as_lme_user "$MASTER_CONTAINER" "sudo chown lme-user:lme-user ~/LME/ansible/inventory/cluster.yml"
    
    echo -e "  ${GREEN}✓${NC} Cluster inventory created"
    
    # Show inventory file
    echo -e "${YELLOW}Inventory file contents:${NC}"
    docker_exec_as_lme_user "$MASTER_CONTAINER" "cat ~/LME/ansible/inventory/cluster.yml"
}

# Function to run elasticsearch.yml on cluster nodes
run_cluster_install() {
    echo -e "${YELLOW}Running cluster installation on nodes as lme-user (this may take a while)...${NC}"
    
    # Use /tmp for temp dirs since lme-user may not have permissions to /opt before become takes effect
    local cmd="cd ~/LME && ANSIBLE_LOCAL_TEMP=/tmp/ansible-tmp ANSIBLE_REMOTE_TEMP=/tmp/ansible-tmp ansible-playbook -i ansible/inventory/cluster.yml ansible/elasticsearch.yml"
    if [ -n "$ANSIBLE_OPTS" ]; then
        cmd="$cmd $ANSIBLE_OPTS"
    fi
    
    docker_exec_as_lme_user "$MASTER_CONTAINER" "$cmd"
    
    echo -e "  ${GREEN}✓${NC} Cluster installation complete"
}

# =============================================================================
# Main execution
# =============================================================================

echo ""
echo -e "${GREEN}Phase 1: Checking Prerequisites${NC}"
echo "================================="
check_containers

echo ""
echo -e "${GREEN}Phase 2: Setting up SSH Infrastructure${NC}"
echo "========================================"

# Install SSH on node2 and node3
install_ssh_server "$NODE2_CONTAINER"
install_ssh_server "$NODE3_CONTAINER"

# Also install SSH client on master (should already have it from Dockerfile, but just in case)
echo -e "${YELLOW}Ensuring SSH client is installed on master...${NC}"
docker_exec "$MASTER_CONTAINER" "apt-get update && apt-get install -y openssh-client sshpass"
echo -e "  ${GREEN}✓${NC} SSH client ready on master"

# Generate SSH key on master
generate_master_ssh_key

# Copy SSH key to nodes
copy_ssh_key_to_node "$NODE2_CONTAINER" "node2"
copy_ssh_key_to_node "$NODE3_CONTAINER" "node3"

# Test SSH connectivity
echo ""
echo -e "${YELLOW}Testing SSH connectivity...${NC}"
test_ssh_connectivity "node2"
test_ssh_connectivity "node3"

echo ""
echo -e "${GREEN}Phase 3: Master Installation${NC}"
echo "=============================="

# Create environment file
create_environment_file

# Install ansible
install_ansible

if [ "$SKIP_MASTER_INSTALL" = "true" ]; then
    echo -e "${YELLOW}Skipping master installation (--skip-master flag)${NC}"
else
    # Run site.yml
    run_master_install
fi

echo ""
echo -e "${GREEN}Phase 4: Cluster Installation${NC}"
echo "==============================="

# Create cluster inventory
create_cluster_inventory

if [ "$SKIP_CLUSTER_INSTALL" = "true" ]; then
    echo -e "${YELLOW}Skipping cluster installation (--skip-cluster flag)${NC}"
else
    # Run elasticsearch.yml on cluster nodes
    run_cluster_install
fi

echo ""
echo -e "${GREEN}=== Cluster Setup Complete ===${NC}"
echo ""
echo -e "${YELLOW}To access the cluster:${NC}"
echo -e "  - Kibana:        https://localhost:5601"
echo -e "  - Elasticsearch: https://localhost:9200"
echo ""
echo -e "${YELLOW}To SSH into containers:${NC}"
echo -e "  - Master:  docker exec -it $MASTER_CONTAINER bash"
echo -e "  - Node 2:  docker exec -it $NODE2_CONTAINER bash"
echo -e "  - Node 3:  docker exec -it $NODE3_CONTAINER bash"
echo ""
echo -e "${YELLOW}To check cluster health:${NC}"
echo -e "  docker exec $MASTER_CONTAINER bash -c 'curl -k -u elastic:\$(cat /etc/lme/vault/elastic) https://localhost:9200/_cluster/health?pretty'"
echo ""
echo -e "${YELLOW}Cleanup:${NC}"
echo -e "  docker compose -f docker-compose-cluster.yml down -v"
