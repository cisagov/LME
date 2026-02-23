#!/bin/bash

# Colors for better readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
LME_DIR="$(dirname "$SCRIPT_DIR")"
INVENTORY_FILE="$LME_DIR/ansible/inventory/cluster.yml"

# Arrays to store node information
declare -a NODE_IPS
declare -a NODE_USERS
declare -a NODE_NAMES

echo "==============================================="
echo "    LME Cluster Inventory Generator"
echo "==============================================="
echo

echo -e "${BLUE}This script will help you create a cluster inventory file for LME installation.${NC}"
echo -e "${BLUE}You'll be asked for information about each node in your cluster.${NC}"
echo
echo -e "${YELLOW}Important: The first node (es1) will be your master node where Kibana, Fleet, and Wazuh run.${NC}"
echo

# Function to validate IP address
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to validate hostname
validate_hostname() {
    local hostname=$1
    # Allow alphanumeric, dots, and hyphens
    if [[ $hostname =~ ^[a-zA-Z0-9][a-zA-Z0-9\.-]*[a-zA-Z0-9]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to validate IP or hostname
validate_ip_or_hostname() {
    local value=$1
    if validate_ip "$value" || validate_hostname "$value"; then
        return 0
    else
        return 1
    fi
}

# Ask for number of nodes
while true; do
    echo -e "${YELLOW}How many nodes will be in your Elasticsearch cluster?${NC}"
    echo -e "${BLUE}Minimum: 3 nodes (recommended for production)${NC}"
    echo -e "${BLUE}This includes the master node where Kibana and Fleet will run.${NC}"
    read -p "> " NUM_NODES

    if [[ "$NUM_NODES" =~ ^[0-9]+$ ]] && [ "$NUM_NODES" -ge 1 ]; then
        if [ "$NUM_NODES" -lt 3 ]; then
            echo -e "${YELLOW}Warning: Clusters with fewer than 3 nodes are not recommended for production.${NC}"
            read -p "Continue anyway? (y/n): " confirm
            if [[ ! $confirm =~ ^[Yy]$ ]]; then
                continue
            fi
        fi
        break
    else
        echo -e "${RED}Please enter a valid number (1 or greater).${NC}"
    fi
done

echo
echo -e "${GREEN}Configuring $NUM_NODES nodes...${NC}"
echo

# Collect information for each node
for i in $(seq 1 $NUM_NODES); do
    NODE_NAME="es$i"

    echo "==============================================="
    if [ $i -eq 1 ]; then
        echo -e "${YELLOW}Configuring Master Node: $NODE_NAME${NC}"
        echo -e "${BLUE}This node will run the full LME stack:${NC}"
        echo -e "${BLUE}  - Elasticsearch (data storage and search)${NC}"
        echo -e "${BLUE}  - Kibana (web interface)${NC}"
        echo -e "${BLUE}  - Fleet (agent management)${NC}"
        echo -e "${BLUE}  - Wazuh (security monitoring)${NC}"
    else
        echo -e "${YELLOW}Configuring Cluster Node: $NODE_NAME${NC}"
        echo -e "${BLUE}This node will run Elasticsearch only for distributed storage.${NC}"
    fi
    echo "==============================================="
    echo

    # Get IP or hostname
    while true; do
        echo -e "${YELLOW}Enter the IP address or hostname for $NODE_NAME:${NC}"
        if [ $i -eq 1 ]; then
            echo -e "${BLUE}This should be the IP/hostname where other nodes can reach this master node.${NC}"
            echo -e "${BLUE}Example: 10.0.0.4 or master.example.com${NC}"
        else
            echo -e "${BLUE}This should be the IP/hostname where the master can reach this node.${NC}"
            echo -e "${BLUE}Example: 10.0.0.$((i+3)) or node$i.example.com${NC}"
        fi
        read -p "> " node_ip

        if validate_ip_or_hostname "$node_ip"; then
            NODE_IPS+=("$node_ip")
            echo -e "${GREEN}✓ Using: $node_ip${NC}"
            break
        else
            echo -e "${RED}Invalid IP address or hostname. Please try again.${NC}"
        fi
    done
    echo

    # Get SSH username (skip for master since it uses local connection)
    if [ $i -eq 1 ]; then
        NODE_USERS+=("local")
        echo -e "${BLUE}Master node will use local connection (no SSH required).${NC}"
    else
        while true; do
            echo -e "${YELLOW}Enter the SSH username for $NODE_NAME:${NC}"
            echo -e "${BLUE}This is the user that can SSH from the master to this node.${NC}"
            echo -e "${BLUE}Passwordless SSH (via SSH keys) is recommended.${NC}"
            echo -e "${BLUE}Example: ubuntu, centos, admin${NC}"
            read -p "> " node_user

            if [ -n "$node_user" ]; then
                NODE_USERS+=("$node_user")
                echo -e "${GREEN}✓ SSH user: $node_user${NC}"
                break
            else
                echo -e "${RED}Username cannot be empty.${NC}"
            fi
        done
    fi
    echo

    # Store node name
    NODE_NAMES+=("$NODE_NAME")

    echo -e "${GREEN}✓ Node $NODE_NAME configured${NC}"
    echo
done

# Display summary
echo "==============================================="
echo -e "${GREEN}Configuration Summary${NC}"
echo "==============================================="
echo
echo -e "${YELLOW}Master Node:${NC}"
echo -e "  Name: ${NODE_NAMES[0]}"
echo -e "  IP/Hostname: ${NODE_IPS[0]}"
echo -e "  Connection: Local"
echo
if [ "$NUM_NODES" -gt 1 ]; then
    echo -e "${YELLOW}Cluster Nodes:${NC}"
    for i in $(seq 2 $NUM_NODES); do
        idx=$((i-1))
        echo -e "  Name: ${NODE_NAMES[$idx]}"
        echo -e "  IP/Hostname: ${NODE_IPS[$idx]}"
        echo -e "  SSH User: ${NODE_USERS[$idx]}"
        echo
    done
fi
echo -e "${YELLOW}Cluster Seed Hosts (for Elasticsearch discovery):${NC}"
for ip in "${NODE_IPS[@]}"; do
    echo -e "  - $ip"
done
echo
echo -e "${YELLOW}Inventory file will be created at:${NC}"
echo -e "  $INVENTORY_FILE"
echo

# Confirm
read -p "Does this look correct? (y/n): " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Configuration cancelled. Please run the script again.${NC}"
    exit 0
fi

# Create inventory directory if it doesn't exist
mkdir -p "$(dirname "$INVENTORY_FILE")"

# Generate the inventory file
echo
echo -e "${YELLOW}Generating inventory file...${NC}"

cat > "$INVENTORY_FILE" << EOF
# LME Cluster Inventory File
# Generated by create_cluster_inventory.sh on $(date)
#
# This file defines the Elasticsearch cluster topology for LME.
# - Master node (${NODE_NAMES[0]}) runs the full LME stack
# - Cluster nodes run Elasticsearch only for distributed storage

all:
  vars:
    # Master node IP - where Kibana and Fleet are accessible
    es_master_host: ${NODE_IPS[0]}

    # All node IPs for cluster discovery
    # These must match the es_publish_host values below
    es_cluster_seed_hosts:
EOF

# Add seed hosts
for ip in "${NODE_IPS[@]}"; do
    echo "      - $ip" >> "$INVENTORY_FILE"
done

# Add children section
cat >> "$INVENTORY_FILE" << EOF

  children:
    elasticsearch:
      hosts:
EOF

# Add master node (always first)
cat >> "$INVENTORY_FILE" << EOF
        # Master node - MUST be first for certificate generation
        ${NODE_NAMES[0]}:
          # ansible_host: IP/hostname for Ansible to SSH/connect to this node
          ansible_host: ${NODE_IPS[0]}
          # ansible_connection: Use 'local' for master (no SSH), 'ssh' for remote nodes
          ansible_connection: local
          # es_node_name: The name this Elasticsearch node uses within the cluster
          es_node_name: lme-elasticsearch
          # es_is_initial_master: Set to true only for the initial master node
          es_is_initial_master: true
          # es_publish_host: IP/hostname this node advertises to other ES nodes
          # This value MUST appear in es_cluster_seed_hosts above
          es_publish_host: ${NODE_IPS[0]}
EOF

# Add remaining nodes
for i in $(seq 2 $NUM_NODES); do
    idx=$((i-1))
    cat >> "$INVENTORY_FILE" << EOF

        # Cluster node $i
        ${NODE_NAMES[$idx]}:
          # ansible_host: IP/hostname for Ansible to SSH to this node
          ansible_host: ${NODE_IPS[$idx]}
          # ansible_user: SSH username for Ansible to connect as
          ansible_user: ${NODE_USERS[$idx]}
          # es_node_name: The name this Elasticsearch node uses within the cluster
          es_node_name: ${NODE_NAMES[$idx]}
          # es_publish_host: IP/hostname this node advertises to other ES nodes
          # This value MUST appear in es_cluster_seed_hosts above
          es_publish_host: ${NODE_IPS[$idx]}
EOF
done

echo
echo -e "${GREEN}✓ Inventory file created successfully!${NC}"
echo

# Display next steps
echo "==============================================="
echo -e "${GREEN}Next Steps${NC}"
echo "==============================================="
echo
echo -e "${YELLOW}1. Verify SSH connectivity from master to cluster nodes:${NC}"
if [ "$NUM_NODES" -gt 1 ]; then
    for i in $(seq 2 $NUM_NODES); do
        idx=$((i-1))
        echo -e "   ssh ${NODE_USERS[$idx]}@${NODE_IPS[$idx]} 'echo Connected to ${NODE_NAMES[$idx]}'"
    done
fi
echo
echo -e "${YELLOW}2. Install Ansible dependencies on the master node:${NC}"
echo -e "   cd $LME_DIR/ansible"
echo -e "   ansible-galaxy collection install -r requirements.yml"
echo
echo -e "${YELLOW}3. Run the main LME installation on the master node:${NC}"
echo -e "   cd $LME_DIR"
echo -e "   ansible-playbook ansible/site.yml \\"
echo -e "     -e lme_cluster_mode=true \\"
echo -e "     -e 'es_cluster_seed_hosts=[\"${NODE_IPS[0]}\"$(for i in $(seq 2 $NUM_NODES); do idx=$((i-1)); echo -n ",\"${NODE_IPS[$idx]}\""; done)]' \\"
echo -e "     -e es_master_publish_host=${NODE_IPS[0]}"
echo
echo -e "${YELLOW}4. Deploy Elasticsearch to all cluster nodes:${NC}"
echo -e "   cd $LME_DIR"
echo -e "   ansible-playbook -i ansible/inventory/cluster.yml ansible/elasticsearch.yml"
echo
echo -e "${YELLOW}5. Verify cluster health:${NC}"
echo -e "   source /opt/lme/scripts/extract_secrets.sh -q"
echo -e "   curl -sk -u elastic:\$elastic https://localhost:9200/_cluster/health?pretty"
echo
echo -e "${GREEN}For detailed instructions, see: testing/v2/development/CLUSTER_INSTALL.md${NC}"
echo

exit 0
