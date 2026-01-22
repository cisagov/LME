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

# Function to run command in a container
docker_exec() {
    local container=$1
    shift
    docker exec "$container" bash -c "$*"
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
    docker_exec "$container" "mkdir -p /root/.ssh && chmod 700 /root/.ssh"
    docker_exec "$container" "sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config"
    docker_exec "$container" "sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config"
    docker_exec "$container" "service ssh start || /usr/sbin/sshd"
    
    echo -e "  ${GREEN}✓${NC} SSH server installed and started on $container"
}

# Function to generate SSH key on master
generate_master_ssh_key() {
    echo -e "${YELLOW}Generating SSH key on master node...${NC}"
    
    # Check if key already exists
    if docker_exec "$MASTER_CONTAINER" "test -f /root/.ssh/id_rsa"; then
        echo -e "  ${GREEN}✓${NC} SSH key already exists on master"
    else
        docker_exec "$MASTER_CONTAINER" "ssh-keygen -t rsa -b 4096 -N '' -f /root/.ssh/id_rsa -q"
        echo -e "  ${GREEN}✓${NC} SSH key generated on master"
    fi
}

# Function to copy SSH key from master to a node
copy_ssh_key_to_node() {
    local node_container=$1
    local node_hostname=$2
    
    echo -e "${YELLOW}Copying SSH key from master to $node_hostname...${NC}"
    
    # Get master's public key
    local pubkey
    pubkey=$(docker_exec "$MASTER_CONTAINER" "cat /root/.ssh/id_rsa.pub")
    
    # Add to node's authorized_keys
    docker_exec "$node_container" "echo '$pubkey' >> /root/.ssh/authorized_keys"
    docker_exec "$node_container" "chmod 600 /root/.ssh/authorized_keys"
    
    # Add node to master's known_hosts
    docker_exec "$MASTER_CONTAINER" "ssh-keyscan -H $node_hostname >> /root/.ssh/known_hosts 2>/dev/null || true"
    
    echo -e "  ${GREEN}✓${NC} SSH key copied to $node_hostname"
}

# Function to test SSH connectivity
test_ssh_connectivity() {
    local node_hostname=$1
    
    echo -e "${YELLOW}Testing SSH connectivity to $node_hostname...${NC}"
    
    if docker_exec "$MASTER_CONTAINER" "ssh -o StrictHostKeyChecking=no -o BatchMode=yes root@$node_hostname hostname"; then
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
    
    # Check if env file already exists
    if docker_exec "$MASTER_CONTAINER" "test -f /root/LME/config/lme-environment.env"; then
        echo -e "  ${YELLOW}lme-environment.env already exists, updating IPVAR...${NC}"
        docker_exec "$MASTER_CONTAINER" "sed -i 's/IPVAR=.*/IPVAR=${master_ip}/' /root/LME/config/lme-environment.env"
    else
        docker_exec "$MASTER_CONTAINER" "cp /root/LME/config/example.env /root/LME/config/lme-environment.env"
        docker_exec "$MASTER_CONTAINER" "sed -i 's/IPVAR=.*/IPVAR=${master_ip}/' /root/LME/config/lme-environment.env"
    fi
    
    echo -e "  ${GREEN}✓${NC} Environment file created with IPVAR=${master_ip}"
}

# Function to install ansible and requirements
install_ansible() {
    echo -e "${YELLOW}Installing ansible and requirements on master...${NC}"
    
    docker_exec "$MASTER_CONTAINER" "apt-get update && apt-get install -y ansible jq"
    docker_exec "$MASTER_CONTAINER" "cd /root/LME/ansible && ansible-galaxy install -r requirements.yml"
    
    echo -e "  ${GREEN}✓${NC} Ansible and requirements installed"
}

# Function to run site.yml on master
run_master_install() {
    echo -e "${YELLOW}Running main installation on master (this may take a while)...${NC}"
    
    # Set Ansible temp directories to avoid I/O errors
    docker_exec "$MASTER_CONTAINER" "mkdir -p /opt/ansible-tmp"
    
    local cmd="cd /root/LME && ANSIBLE_LOCAL_TEMP=/opt/ansible-tmp ANSIBLE_REMOTE_TEMP=/opt/ansible-tmp ansible-playbook ansible/site.yml"
    if [ -n "$ANSIBLE_OPTS" ]; then
        cmd="$cmd $ANSIBLE_OPTS"
    fi
    
    docker_exec "$MASTER_CONTAINER" "$cmd"
    
    echo -e "  ${GREEN}✓${NC} Main installation complete on master"
}

# Function to create cluster inventory
create_cluster_inventory() {
    echo -e "${YELLOW}Creating cluster inventory file...${NC}"
    
    # Create the inventory file
    docker_exec "$MASTER_CONTAINER" "cat > /root/LME/ansible/inventory/cluster.yml << 'EOF'
all:
  children:
    elasticsearch:
      hosts:
        es2:
          ansible_host: node2
          ansible_user: root
        es3:
          ansible_host: node3
          ansible_user: root
EOF"
    
    echo -e "  ${GREEN}✓${NC} Cluster inventory created"
    
    # Show inventory file
    echo -e "${YELLOW}Inventory file contents:${NC}"
    docker_exec "$MASTER_CONTAINER" "cat /root/LME/ansible/inventory/cluster.yml"
}

# Function to run elasticsearch.yml on cluster nodes
run_cluster_install() {
    echo -e "${YELLOW}Running cluster installation on nodes (this may take a while)...${NC}"
    
    local cmd="cd /root/LME && ANSIBLE_LOCAL_TEMP=/opt/ansible-tmp ANSIBLE_REMOTE_TEMP=/opt/ansible-tmp ansible-playbook -i ansible/inventory/cluster.yml ansible/elasticsearch.yml"
    if [ -n "$ANSIBLE_OPTS" ]; then
        cmd="$cmd $ANSIBLE_OPTS"
    fi
    
    docker_exec "$MASTER_CONTAINER" "$cmd"
    
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
