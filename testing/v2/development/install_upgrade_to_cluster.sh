#!/bin/bash

# LME Docker Upgrade-to-Cluster Install Script
#
# Tests the upgrade path: single-node install -> convert to cluster
# Run from: testing/v2/development
#
# This script:
#   1. Brings up docker-compose-cluster containers
#   2. Sets up SSH between containers
#   3. Installs single-node LME on node1 via install.sh
#   4. Creates cluster inventory
#   5. Runs convert_to_cluster.sh to upgrade to multi-node cluster

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Container names
MASTER_CONTAINER="lme_cluster_node1"
NODE2_CONTAINER="lme_cluster_node2"
NODE3_CONTAINER="lme_cluster_node3"
NFS_CONTAINER="lme_cluster_nfs"

# Default options
DEBUG_MODE="false"
SKIP_DOCKER="false"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--debug)
            DEBUG_MODE="true"
            shift
            ;;
        --skip-docker)
            SKIP_DOCKER="true"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Tests the upgrade path: single-node install -> convert to cluster"
            echo ""
            echo "OPTIONS:"
            echo "  -d, --debug      Enable debug mode for verbose ansible output"
            echo "  --skip-docker    Skip bringing up containers (use if already running)"
            echo "  -h, --help       Show this help message"
            echo ""
            echo "This script brings up the cluster, installs single-node LME on node1,"
            echo "then runs convert_to_cluster.sh to upgrade to a 3-node cluster."
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose-cluster.yml"

echo -e "${GREEN}=== LME Docker Upgrade-to-Cluster Installer ===${NC}"
echo "Script directory: $SCRIPT_DIR"
if [ "$DEBUG_MODE" = "true" ]; then
    echo -e "${YELLOW}Debug mode: ENABLED${NC}"
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

# Function to ensure .env exists for docker compose (HOST_UID, HOST_GID)
ensure_env_file() {
    local env_file="$SCRIPT_DIR/.env"
    if [ ! -f "$env_file" ]; then
        echo -e "${YELLOW}Creating .env file for docker compose...${NC}"
        echo "HOST_UID=$(id -u)" > "$env_file"
        echo "HOST_GID=$(id -g)" >> "$env_file"
        echo -e "  ${GREEN}✓${NC} Created .env with HOST_UID=$(id -u) HOST_GID=$(id -g)"
    else
        echo -e "${GREEN}✓${NC} .env already exists"
    fi
}

# Function to bring up docker-compose-cluster
bring_up_cluster() {
    echo -e "${YELLOW}Bringing up cluster containers...${NC}"
    cd "$SCRIPT_DIR"
    docker compose -f "$COMPOSE_FILE" up -d --build
    echo -e "  ${GREEN}✓${NC} Cluster containers started"
    # Give containers a moment to fully start
    sleep 5
}

# Function to check if containers are running
check_containers() {
    echo -e "${YELLOW}Checking if containers are running...${NC}"
    for container in "$MASTER_CONTAINER" "$NODE2_CONTAINER" "$NODE3_CONTAINER" "$NFS_CONTAINER"; do
        if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            echo -e "${RED}Error: Container $container is not running${NC}"
            echo -e "${YELLOW}Start the cluster first or run without --skip-docker:${NC}"
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
    docker_exec "$container" "mkdir -p /home/lme-user/.ssh && chmod 700 /home/lme-user/.ssh && chown lme-user:lme-user /home/lme-user/.ssh"
    docker_exec "$container" "rm -f /run/nologin /var/run/nologin /etc/nologin"
    docker_exec "$container" "service ssh start || /usr/sbin/sshd"
    echo -e "  ${GREEN}✓${NC} SSH server installed and started on $container"
}

# Function to generate SSH key on master for lme-user
generate_master_ssh_key() {
    echo -e "${YELLOW}Generating SSH key on master node for lme-user...${NC}"
    docker_exec "$MASTER_CONTAINER" "mkdir -p /home/lme-user/.ssh && chmod 700 /home/lme-user/.ssh && chown lme-user:lme-user /home/lme-user/.ssh"
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
    local pubkey
    pubkey=$(docker_exec_as_lme_user "$MASTER_CONTAINER" "cat ~/.ssh/id_rsa.pub")
    docker_exec "$node_container" "echo '$pubkey' >> /home/lme-user/.ssh/authorized_keys"
    docker_exec "$node_container" "chmod 600 /home/lme-user/.ssh/authorized_keys"
    docker_exec "$node_container" "chown lme-user:lme-user /home/lme-user/.ssh/authorized_keys"
    docker_exec_as_lme_user "$MASTER_CONTAINER" "ssh-keyscan -H $node_hostname >> ~/.ssh/known_hosts 2>/dev/null || true"
    echo -e "  ${GREEN}✓${NC} SSH key copied to $node_hostname"
}

# Function to test SSH connectivity
test_ssh_connectivity() {
    local node_hostname=$1
    echo -e "${YELLOW}Testing SSH connectivity to $node_hostname...${NC}"
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
    local master_ip
    master_ip=$(docker_exec "$MASTER_CONTAINER" "hostname -I | awk '{print \$1}'")
    echo -e "  Master IP: $master_ip"
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
    docker_exec "$MASTER_CONTAINER" "apt-get update && apt-get install -y ansible jq"
    echo -e "${YELLOW}Attempting ansible-galaxy install (may fail if Galaxy is unavailable)...${NC}"
    if docker_exec_as_lme_user "$MASTER_CONTAINER" "cd ~/LME/ansible && ansible-galaxy collection install -r requirements.yml --timeout 30" 2>&1; then
        echo -e "  ${GREEN}✓${NC} Galaxy collections installed"
    else
        echo -e "  ${YELLOW}⚠${NC} Galaxy install failed (server may be unavailable), continuing..."
    fi
    echo -e "  ${GREEN}✓${NC} Ansible installed"
}

# Function to run single-node install via install.sh
run_single_node_install() {
    echo -e "${YELLOW}Running single-node LME install on master via install.sh (this may take a while)...${NC}"
    docker_exec "$MASTER_CONTAINER" "mkdir -p /tmp/ansible-tmp && chmod 777 /tmp/ansible-tmp"
    local cmd="cd ~/LME && NON_INTERACTIVE=true bash install.sh"
    if [ "$DEBUG_MODE" = "true" ]; then
        cmd="$cmd -d"
    fi
    # install.sh may return non-zero if optional steps (fleet/kibana) time out; continue for upgrade test
    docker_exec_as_lme_user "$MASTER_CONTAINER" "$cmd" || true
    echo -e "  ${GREEN}✓${NC} Single-node installation complete"
}

# Function to wait for Elasticsearch to be healthy
wait_for_es_healthy() {
    echo -e "${YELLOW}Waiting for Elasticsearch to be healthy...${NC}"
    local max_attempts=24
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        local status
        status=$(docker_exec "$MASTER_CONTAINER" "sudo bash -c 'source /opt/lme/scripts/extract_secrets.sh -q 2>/dev/null && curl -sk -u \"elastic:\$elastic\" https://localhost:9200/_cluster/health 2>/dev/null'" 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || true)
        if [[ "$status" == "green" || "$status" == "yellow" ]]; then
            echo -e "  ${GREEN}✓${NC} Elasticsearch is $status (attempt $attempt/$max_attempts)"
            return 0
        fi
        echo -e "  Attempt $attempt/$max_attempts: ES not ready (status: ${status:-unreachable}), waiting 30s..."
        sleep 30
        ((attempt++))
    done
    echo -e "${RED}Error: Elasticsearch did not become healthy after ${max_attempts} attempts${NC}"
    exit 1
}

# Function to create cluster inventory
create_cluster_inventory() {
    echo -e "${YELLOW}Creating cluster inventory file...${NC}"
    docker_exec_as_lme_user "$MASTER_CONTAINER" "sudo tee ~/LME/ansible/inventory/cluster.yml > /dev/null << 'EOF'
all:
  vars:
    es_master_host: node1
    es_cluster_seed_hosts:
      - node1
      - node2
      - node3
  children:
    elasticsearch:
      hosts:
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
    docker_exec_as_lme_user "$MASTER_CONTAINER" "sudo chown lme-user:lme-user ~/LME/ansible/inventory/cluster.yml"
    echo -e "  ${GREEN}✓${NC} Cluster inventory created"
    echo -e "${YELLOW}Inventory file contents:${NC}"
    docker_exec_as_lme_user "$MASTER_CONTAINER" "cat ~/LME/ansible/inventory/cluster.yml"
}

# Function to run convert_to_cluster.sh
run_convert_to_cluster() {
    echo -e "${YELLOW}Running convert_to_cluster.sh (upgrade to cluster)...${NC}"
    local cmd="cd ~/LME && bash scripts/convert_to_cluster.sh --skip-inventory --skip-prompts"
    if [ "$DEBUG_MODE" = "true" ]; then
        echo -e "${BLUE}Note: convert_to_cluster.sh does not have a debug flag; ansible output will be standard${NC}"
    fi
    # Run as lme-user so ~/LME resolves to /home/lme-user/LME (LME is mounted there)
    docker_exec_as_lme_user "$MASTER_CONTAINER" "$cmd"
    echo -e "  ${GREEN}✓${NC} Conversion to cluster complete"
}

# =============================================================================
# Main execution
# =============================================================================

echo ""
echo -e "${GREEN}Phase 0: Docker Cluster Setup${NC}"
echo "=============================="
ensure_env_file
if [ "$SKIP_DOCKER" = "true" ]; then
    echo -e "${YELLOW}Skipping docker compose (--skip-docker)${NC}"
else
    bring_up_cluster
fi
check_containers

echo ""
echo -e "${GREEN}Phase 1: SSH Infrastructure${NC}"
echo "============================"
install_ssh_server "$NODE2_CONTAINER"
install_ssh_server "$NODE3_CONTAINER"
echo -e "${YELLOW}Ensuring SSH client is installed on master...${NC}"
docker_exec "$MASTER_CONTAINER" "apt-get update && apt-get install -y openssh-client sshpass"
echo -e "  ${GREEN}✓${NC} SSH client ready on master"
generate_master_ssh_key
copy_ssh_key_to_node "$NODE2_CONTAINER" "node2"
copy_ssh_key_to_node "$NODE3_CONTAINER" "node3"
echo ""
echo -e "${YELLOW}Testing SSH connectivity...${NC}"
test_ssh_connectivity "node2"
test_ssh_connectivity "node3"

echo ""
echo -e "${GREEN}Phase 2: Prepare Master for Single-Node Install${NC}"
echo "=================================================="
create_environment_file
install_ansible

echo ""
echo -e "${GREEN}Phase 3: Single-Node LME Install${NC}"
echo "================================"
run_single_node_install

echo ""
echo -e "${GREEN}Phase 4: Verify Elasticsearch Health${NC}"
echo "===================================="
wait_for_es_healthy

echo ""
echo -e "${GREEN}Phase 5: Create Cluster Inventory${NC}"
echo "==============================="
create_cluster_inventory

echo ""
echo -e "${GREEN}Phase 6: Convert to Cluster${NC}"
echo "======================="
run_convert_to_cluster

echo ""
echo -e "${GREEN}=== Upgrade-to-Cluster Complete ===${NC}"
echo ""
echo -e "${YELLOW}To access the cluster:${NC}"
echo -e "  - Kibana:        https://localhost:5601"
echo -e "  - Elasticsearch: https://localhost:9200"
echo ""
echo -e "${YELLOW}To check cluster health:${NC}"
echo -e "  docker exec $MASTER_CONTAINER bash -c 'source /opt/lme/scripts/extract_secrets.sh -q && curl -sk -u \"elastic:\$elastic\" https://localhost:9200/_cluster/health?pretty'"
echo ""
echo -e "${YELLOW}To see cluster nodes:${NC}"
echo -e "  docker exec $MASTER_CONTAINER bash -c 'source /opt/lme/scripts/extract_secrets.sh -q && curl -sk -u \"elastic:\$elastic\" https://localhost:9200/_cat/nodes?v'"
echo ""
echo -e "${YELLOW}Cleanup:${NC}"
echo -e "  docker compose -f $COMPOSE_FILE down -v"
echo ""
