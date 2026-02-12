#!/bin/bash

# LME Docker RHEL9 Cluster Install Script
# Run from host while docker-compose-cluster.yml containers are running.
# This sets up SSH between cluster containers and runs Ansible for cluster install.
#
# Uses lme-user (with passwordless sudo) for SSH between nodes, matching the
# Ubuntu cluster install approach.

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

MASTER_CONTAINER="lme_rhel9_cluster_node1"
NODE2_CONTAINER="lme_rhel9_cluster_node2"
NODE3_CONTAINER="lme_rhel9_cluster_node3"

DEBUG_MODE="false"
SKIP_MASTER_INSTALL="false"
SKIP_CLUSTER_INSTALL="false"

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
            echo "  --skip-master      Skip master installation (ansible/site.yml)"
            echo "  --skip-cluster     Skip cluster installation (ansible/elasticsearch.yml)"
            echo "  -h, --help         Show this help message"
            echo ""
            echo "Prerequisites:"
            echo "  docker compose -f docker-compose-cluster.yml up -d --build"
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${GREEN}=== LME Docker RHEL9 Cluster Installer ===${NC}"
echo "Script directory: $SCRIPT_DIR"

ANSIBLE_OPTS=""
if [ "$DEBUG_MODE" = "true" ]; then
    ANSIBLE_OPTS="-e debug_mode=true -v"
    echo -e "${YELLOW}Debug mode enabled${NC}"
fi

# Run command in a container as root
docker_exec() {
    local container=$1
    shift
    docker exec "$container" bash -c "$*"
}

# Run command in a container as lme-user
docker_exec_as_lme_user() {
    local container=$1
    shift
    docker exec -u lme-user "$container" bash -c "$*"
}

check_containers() {
    echo -e "${YELLOW}Checking cluster containers...${NC}"
    for container in "$MASTER_CONTAINER" "$NODE2_CONTAINER" "$NODE3_CONTAINER"; do
        if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            echo -e "${RED}Error: ${container} is not running${NC}"
            echo -e "Run from ${SCRIPT_DIR}:"
            echo -e "  docker compose -f docker-compose-cluster.yml up -d --build"
            exit 1
        fi
        echo -e "  ${GREEN}✓${NC} ${container} is running"
    done
}

install_ssh_server() {
    local container=$1
    echo -e "${YELLOW}Installing SSH server on ${container}...${NC}"
    docker_exec "$container" "dnf install -y openssh-server"
    # Set up SSH directory for lme-user
    docker_exec "$container" "mkdir -p /home/lme-user/.ssh /run/sshd && chmod 700 /home/lme-user/.ssh && chown lme-user:lme-user /home/lme-user/.ssh"
    docker_exec "$container" "rm -f /run/nologin /var/run/nologin /etc/nologin"
    # Fix PAM sshd account check for UBI9 containers.
    # The default pam_sepermit / pam_nologin / pam_unix account stack blocks
    # SSH for all users in containers without SELinux. Replace the account
    # lines with pam_permit.so so key-based auth works for lme-user.
    docker_exec "$container" "sed -i '/^account/d' /etc/pam.d/sshd"
    docker_exec "$container" "sed -i '/^password/i account    required     pam_permit.so' /etc/pam.d/sshd"
    docker_exec "$container" "systemctl restart sshd || systemctl start sshd || /usr/sbin/sshd"
    echo -e "  ${GREEN}✓${NC} SSH ready on ${container}"
}

generate_master_ssh_key() {
    echo -e "${YELLOW}Generating SSH key on master for lme-user...${NC}"
    docker_exec "$MASTER_CONTAINER" "mkdir -p /home/lme-user/.ssh && chmod 700 /home/lme-user/.ssh && chown lme-user:lme-user /home/lme-user/.ssh"
    if docker_exec_as_lme_user "$MASTER_CONTAINER" "test -f ~/.ssh/id_rsa"; then
        echo -e "  ${GREEN}✓${NC} SSH key already exists"
    else
        docker_exec_as_lme_user "$MASTER_CONTAINER" "ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/id_rsa -q"
        echo -e "  ${GREEN}✓${NC} SSH key generated"
    fi
}

copy_ssh_key_to_node() {
    local node_container=$1
    local node_host=$2
    echo -e "${YELLOW}Copying SSH key to ${node_host}...${NC}"
    local pubkey
    pubkey=$(docker_exec_as_lme_user "$MASTER_CONTAINER" "cat ~/.ssh/id_rsa.pub")
    docker_exec "$node_container" "echo '$pubkey' >> /home/lme-user/.ssh/authorized_keys"
    docker_exec "$node_container" "chmod 600 /home/lme-user/.ssh/authorized_keys"
    docker_exec "$node_container" "chown lme-user:lme-user /home/lme-user/.ssh/authorized_keys"
    docker_exec_as_lme_user "$MASTER_CONTAINER" "ssh-keyscan -H ${node_host} >> ~/.ssh/known_hosts 2>/dev/null || true"
    echo -e "  ${GREEN}✓${NC} SSH trust configured for ${node_host}"
}

test_ssh_connectivity() {
    local node_host=$1
    echo -e "${YELLOW}Testing SSH to ${node_host}...${NC}"
    if docker_exec_as_lme_user "$MASTER_CONTAINER" "ssh -o StrictHostKeyChecking=no -o BatchMode=yes lme-user@${node_host} 'echo connected-ok'"; then
        echo -e "  ${GREEN}✓${NC} SSH to ${node_host} works"
    else
        echo -e "  ${RED}✗${NC} SSH to ${node_host} failed"
        exit 1
    fi
}

create_environment_file() {
    echo -e "${YELLOW}Creating config/lme-environment.env on master...${NC}"
    local master_ip
    master_ip=$(docker_exec "$MASTER_CONTAINER" "ip -4 -o addr show eth0 | awk '{print \$4}' | cut -d/ -f1")
    echo -e "  Master IP: $master_ip"
    if docker_exec_as_lme_user "$MASTER_CONTAINER" "test -f ~/LME/config/lme-environment.env"; then
        echo -e "  ${YELLOW}lme-environment.env already exists, updating IPVAR...${NC}"
        docker_exec_as_lme_user "$MASTER_CONTAINER" "sed -i 's/IPVAR=.*/IPVAR=${master_ip}/' ~/LME/config/lme-environment.env"
    else
        docker_exec_as_lme_user "$MASTER_CONTAINER" "cp ~/LME/config/example.env ~/LME/config/lme-environment.env"
        docker_exec_as_lme_user "$MASTER_CONTAINER" "sed -i 's/IPVAR=.*/IPVAR=${master_ip}/' ~/LME/config/lme-environment.env"
    fi
    echo -e "  ${GREEN}✓${NC} IPVAR set to ${master_ip}"
}

install_ansible() {
    echo -e "${YELLOW}Installing Ansible and jq on master...${NC}"
    if docker_exec "$MASTER_CONTAINER" "dnf install -y ansible-core jq" 2>&1; then
        echo -e "  ${GREEN}✓${NC} Installed ansible-core from dnf"
    else
        echo -e "  ${YELLOW}⚠${NC} dnf ansible-core install failed, falling back to pip"
        docker_exec "$MASTER_CONTAINER" "dnf install -y python3 python3-pip jq"
        docker_exec "$MASTER_CONTAINER" "python3 -m pip install --upgrade pip"
        docker_exec "$MASTER_CONTAINER" "python3 -m pip install ansible-core"
        # Symlink pip-installed ansible binaries into /usr/bin so that
        # sudo -i (used by extract_secrets.sh) can find them.
        docker_exec "$MASTER_CONTAINER" "for f in /usr/local/bin/ansible*; do ln -sf \"\$f\" /usr/bin/; done"
        echo -e "  ${GREEN}✓${NC} Installed ansible-core via pip (symlinked to /usr/bin)"
    fi
    echo -e "${YELLOW}Attempting ansible-galaxy collection install...${NC}"
    if docker_exec_as_lme_user "$MASTER_CONTAINER" "cd ~/LME/ansible && ansible-galaxy collection install -r requirements.yml --timeout 30" 2>&1; then
        echo -e "  ${GREEN}✓${NC} Ansible collections installed"
    else
        echo -e "  ${YELLOW}⚠${NC} Galaxy install failed, continuing with current collections"
    fi
}

run_master_install() {
    echo -e "${YELLOW}Running ansible/site.yml on master as lme-user (this may take a while)...${NC}"
    docker_exec "$MASTER_CONTAINER" "mkdir -p /tmp/ansible-tmp && chmod 777 /tmp/ansible-tmp"
    local cmd="cd ~/LME && ANSIBLE_LOCAL_TEMP=/tmp/ansible-tmp ANSIBLE_REMOTE_TEMP=/tmp/ansible-tmp ansible-playbook ansible/site.yml -e lme_cluster_mode=true -e '{\"es_cluster_seed_hosts\": [\"node1\", \"node2\", \"node3\"]}' -e es_master_publish_host=node1"
    if [ -n "$ANSIBLE_OPTS" ]; then
        cmd="$cmd $ANSIBLE_OPTS"
    fi
    docker_exec_as_lme_user "$MASTER_CONTAINER" "$cmd"
    echo -e "  ${GREEN}✓${NC} Master install complete"
}

create_cluster_inventory() {
    echo -e "${YELLOW}Creating ansible/inventory/cluster.yml...${NC}"
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
    echo -e "  ${GREEN}✓${NC} Inventory created"
}

run_cluster_install() {
    echo -e "${YELLOW}Running ansible/elasticsearch.yml for cluster nodes...${NC}"
    local cmd="cd ~/LME && ANSIBLE_LOCAL_TEMP=/tmp/ansible-tmp ANSIBLE_REMOTE_TEMP=/tmp/ansible-tmp ansible-playbook -i ansible/inventory/cluster.yml ansible/elasticsearch.yml"
    if [ -n "$ANSIBLE_OPTS" ]; then
        cmd="$cmd $ANSIBLE_OPTS"
    fi
    docker_exec_as_lme_user "$MASTER_CONTAINER" "$cmd"
    echo -e "  ${GREEN}✓${NC} Cluster install complete"
}

echo ""
echo -e "${GREEN}Phase 1: Prerequisites${NC}"
echo "======================"
check_containers

echo ""
echo -e "${GREEN}Phase 2: SSH Setup${NC}"
echo "=================="
install_ssh_server "$NODE2_CONTAINER"
install_ssh_server "$NODE3_CONTAINER"
echo -e "${YELLOW}Ensuring SSH client is installed on master...${NC}"
docker_exec "$MASTER_CONTAINER" "dnf install -y openssh-clients sshpass"
echo -e "  ${GREEN}✓${NC} SSH client ready on master"
generate_master_ssh_key
copy_ssh_key_to_node "$NODE2_CONTAINER" node2
copy_ssh_key_to_node "$NODE3_CONTAINER" node3
test_ssh_connectivity node2
test_ssh_connectivity node3

echo ""
echo -e "${GREEN}Phase 3: Master Install${NC}"
echo "======================="
create_environment_file
install_ansible
if [ "$SKIP_MASTER_INSTALL" = "true" ]; then
    echo -e "${YELLOW}Skipping master install${NC}"
else
    run_master_install
fi

echo ""
echo -e "${GREEN}Phase 4: Cluster Install${NC}"
echo "========================"
create_cluster_inventory
if [ "$SKIP_CLUSTER_INSTALL" = "true" ]; then
    echo -e "${YELLOW}Skipping cluster install${NC}"
else
    run_cluster_install
fi

echo ""
echo -e "${GREEN}=== RHEL9 Cluster Setup Complete ===${NC}"
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
echo -e "  docker exec $MASTER_CONTAINER bash -c 'source /nix/var/nix/profiles/default/etc/profile.d/nix.sh; source /opt/lme/scripts/extract_secrets.sh -q && curl -sk -u elastic:\$elastic https://localhost:9200/_cluster/health?pretty'"
echo ""
echo -e "${YELLOW}Cleanup:${NC}"
echo -e "  docker compose -f docker-compose-cluster.yml down -v"
