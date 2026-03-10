#!/bin/bash
#
# convert_to_cluster.sh
#
# Converts an existing single-node LME installation into a multi-node
# Elasticsearch cluster. This is a convenience wrapper around:
#   1. scripts/create_cluster_inventory.sh  (generate inventory)
#   2. ansible-playbook ansible/convert_to_cluster.yml  (run conversion)
#
# Usage:
#   bash scripts/convert_to_cluster.sh
#   bash scripts/convert_to_cluster.sh --skip-inventory   # if inventory already exists
#   bash scripts/convert_to_cluster.sh --skip-prompts     # for CI / non-interactive

# Colors for better readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
LME_DIR="$(dirname "$SCRIPT_DIR")"
INVENTORY_FILE="$LME_DIR/ansible/inventory/cluster.yml"
PLAYBOOK="$LME_DIR/ansible/convert_to_cluster.yml"
SKIP_INVENTORY=false
SKIP_PROMPTS=false

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Converts a single-node LME installation to a multi-node cluster."
    echo
    echo "OPTIONS:"
    echo "  --skip-inventory    Skip inventory generation (use existing cluster.yml)"
    echo "  --skip-prompts      Skip interactive prompts (for CI/automation)"
    echo "  -h, --help          Show this help message"
    echo
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-inventory)
            SKIP_INVENTORY=true
            shift
            ;;
        --skip-prompts)
            SKIP_PROMPTS=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

echo "==============================================="
echo "    LME Single-Node to Cluster Conversion"
echo "==============================================="
echo

# Pre-flight checks
echo -e "${BLUE}Running pre-flight checks...${NC}"

# Check the user can sudo (needed for ansible become and extract_secrets.sh)
if ! sudo -n true 2>/dev/null; then
    echo -e "${RED}ERROR: This script requires passwordless sudo. Please configure sudo or run 'sudo -v' first.${NC}"
    exit 1
fi

# Check LME is installed (file may be root-owned, so use sudo)
if ! sudo test -f /opt/lme/lme-environment.env; then
    echo -e "${RED}ERROR: LME does not appear to be installed (/opt/lme/lme-environment.env not found).${NC}"
    exit 1
fi

# Check Elasticsearch is responding
echo -e "${BLUE}Checking Elasticsearch health...${NC}"
export PATH=$PATH:/nix/var/nix/profiles/default/bin
# extract_secrets.sh requires podman and ansible-vault on PATH; source the
# profile first so that nix-installed tools are visible.
if [ -f "$HOME/.profile" ]; then
    . "$HOME/.profile" 2>/dev/null || true
fi
source "$LME_DIR/scripts/extract_secrets.sh" -q 2>/dev/null
if [ -z "$elastic" ]; then
    echo -e "${YELLOW}WARNING: extract_secrets.sh did not set \$elastic, retrying with explicit PATH...${NC}"
    export PATH=$PATH:/nix/var/nix/profiles/default/bin:/usr/local/bin
    source "$LME_DIR/scripts/extract_secrets.sh" -q 2>/dev/null
fi
if [ -z "$elastic" ]; then
    echo -e "${RED}ERROR: Could not extract elastic password. Check that ansible-vault and podman are available.${NC}"
    exit 1
fi
ES_HEALTH=$(curl -sk -u "elastic:$elastic" https://localhost:9200/_cluster/health 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$ES_HEALTH" ]; then
    echo -e "${RED}ERROR: Cannot reach Elasticsearch. Is the LME service running?${NC}"
    echo -e "${YELLOW}Try: sudo systemctl status lme${NC}"
    exit 1
fi

NODE_COUNT=$(echo "$ES_HEALTH" | grep -o '"number_of_nodes":[0-9]*' | cut -d: -f2)
echo -e "${BLUE}Current node count: $NODE_COUNT${NC}"

# Check for partial upgrade state (quadlet already in cluster mode but not all nodes joined)
QUADLET_FILE="/etc/containers/systemd/lme-elasticsearch.container"
IS_SINGLE_NODE_CONFIG=$(sudo grep -c 'discovery.type=single-node' "$QUADLET_FILE" 2>/dev/null)
[ -z "$IS_SINGLE_NODE_CONFIG" ] && IS_SINGLE_NODE_CONFIG=0
PARTIAL_UPGRADE=false

if [ "$IS_SINGLE_NODE_CONFIG" = "0" ] && [ "$NODE_COUNT" = "1" ]; then
    PARTIAL_UPGRADE=true
    echo -e "${YELLOW}PARTIAL UPGRADE DETECTED: The quadlet is already in cluster mode${NC}"
    echo -e "${YELLOW}but only 1 node is present. Will resume the previous conversion.${NC}"
    echo
elif [ "$NODE_COUNT" != "1" ]; then
    echo -e "${RED}ERROR: This installation already has $NODE_COUNT nodes.${NC}"
    echo -e "${RED}This script is intended for single-node installations or resuming a partial upgrade.${NC}"
    exit 1
fi

echo -e "${GREEN}Pre-flight checks passed.${NC}"
echo

# Step 1: Generate cluster inventory
if [ "$SKIP_INVENTORY" = true ]; then
    if [ ! -f "$INVENTORY_FILE" ]; then
        echo -e "${RED}ERROR: --skip-inventory was set but $INVENTORY_FILE does not exist.${NC}"
        echo -e "${YELLOW}Run without --skip-inventory or create the inventory manually.${NC}"
        exit 1
    fi
    echo -e "${BLUE}Using existing inventory: $INVENTORY_FILE${NC}"
else
    echo -e "${YELLOW}Step 1: Generate cluster inventory${NC}"
    echo -e "${BLUE}This will create the inventory file defining your cluster nodes.${NC}"
    echo
    bash "$SCRIPT_DIR/create_cluster_inventory.sh"
    if [ $? -ne 0 ]; then
        echo -e "${RED}ERROR: Inventory generation failed or was cancelled.${NC}"
        exit 1
    fi
fi

# Verify inventory exists
if [ ! -f "$INVENTORY_FILE" ]; then
    echo -e "${RED}ERROR: Cluster inventory not found at $INVENTORY_FILE${NC}"
    exit 1
fi

# Step 1.5: Verify SSH connectivity to remote cluster nodes
echo -e "${BLUE}Checking SSH connectivity to cluster nodes...${NC}"
SSH_FAILED=false
# Extract ansible_host values for non-local hosts from the inventory
REMOTE_HOSTS=$(python3 -c "
import yaml, sys
with open('$INVENTORY_FILE') as f:
    inv = yaml.safe_load(f)
children = inv.get('all', {}).get('children', {})
es_hosts = children.get('elasticsearch', {}).get('hosts', {})
for name, vars in es_hosts.items():
    if vars.get('ansible_connection') == 'local':
        continue
    host = vars.get('ansible_host', name)
    user = vars.get('ansible_user', 'lme-user')
    print(f'{user}@{host}')
" 2>/dev/null)

if [ -n "$REMOTE_HOSTS" ]; then
    for target in $REMOTE_HOSTS; do
        echo -n "  Testing SSH to $target... "
        if ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$target" echo ok 2>/dev/null; then
            echo -e "${GREEN}OK${NC}"
        else
            echo -e "${RED}FAILED${NC}"
            SSH_FAILED=true
        fi
    done
    echo
    if [ "$SSH_FAILED" = true ]; then
        echo -e "${RED}ERROR: SSH connectivity check failed for one or more cluster nodes.${NC}"
        echo -e "${YELLOW}Please ensure:${NC}"
        echo -e "${YELLOW}  1. SSH keys are distributed to all cluster nodes${NC}"
        echo -e "${YELLOW}  2. The remote user can accept SSH connections${NC}"
        echo -e "${YELLOW}  3. sshd is running on all cluster nodes${NC}"
        echo -e "${YELLOW}Example: ssh-copy-id lme-user@<node-ip>${NC}"
        exit 1
    fi
    echo -e "${GREEN}SSH connectivity verified to all cluster nodes.${NC}"
else
    echo -e "${YELLOW}No remote hosts found in inventory (all local connections).${NC}"
fi
echo

echo
echo -e "${YELLOW}Step 2: Run conversion playbook${NC}"
echo -e "${BLUE}This will reconfigure the master, regenerate certificates,${NC}"
echo -e "${BLUE}deploy Elasticsearch to cluster nodes, and update replicas.${NC}"
echo

if [ "$SKIP_PROMPTS" = false ]; then
    read -p "Ready to proceed with conversion? (y/n): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Conversion cancelled.${NC}"
        exit 0
    fi
fi

# Build ansible-playbook command
ANSIBLE_CMD="ansible-playbook --become -i $INVENTORY_FILE $PLAYBOOK"
if [ "$SKIP_PROMPTS" = true ]; then
    ANSIBLE_CMD="$ANSIBLE_CMD -e skip_prompts=true"
fi

echo -e "${BLUE}Running: $ANSIBLE_CMD${NC}"
echo

$ANSIBLE_CMD
RESULT=$?

echo
if [ $RESULT -eq 0 ]; then
    echo -e "${GREEN}===============================================${NC}"
    echo -e "${GREEN}  Conversion completed successfully!${NC}"
    echo -e "${GREEN}===============================================${NC}"
    echo
    echo -e "${BLUE}Verify your cluster with:${NC}"
    echo -e "  source /opt/lme/scripts/extract_secrets.sh -p"
    echo -e "  curl -sk -u elastic:\$elastic https://localhost:9200/_cluster/health?pretty"
  echo -e "  curl -sk -u elastic:\$elastic https://localhost:9200/_cat/nodes?v"
else
    echo -e "${RED}===============================================${NC}"
    echo -e "${RED}  Conversion encountered errors (exit code: $RESULT)${NC}"
    echo -e "${RED}===============================================${NC}"
    echo
    echo -e "${YELLOW}Check the Ansible output above for details.${NC}"
    echo -e "${YELLOW}If needed, restore from backup. See:${NC}"
    echo -e "${YELLOW}  testing/v2/development/converting_to_cluster.md${NC}"
    exit $RESULT
fi

exit 0
