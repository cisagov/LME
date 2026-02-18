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
#   sudo bash scripts/convert_to_cluster.sh
#   sudo bash scripts/convert_to_cluster.sh --skip-inventory   # if inventory already exists
#   sudo bash scripts/convert_to_cluster.sh --skip-prompts     # for CI / non-interactive

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

# Check we are root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}ERROR: This script must be run as root (sudo).${NC}"
    exit 1
fi

# Check LME is installed
if [ ! -f /opt/lme/lme-environment.env ]; then
    echo -e "${RED}ERROR: LME does not appear to be installed (/opt/lme/lme-environment.env not found).${NC}"
    exit 1
fi

# Check Elasticsearch is responding
echo -e "${BLUE}Checking Elasticsearch health...${NC}"
export PATH=$PATH:/nix/var/nix/profiles/default/bin
source "$LME_DIR/scripts/extract_secrets.sh" -q 2>/dev/null
ES_HEALTH=$(curl -sk -u "elastic:$lme_elastic_password" https://localhost:9200/_cluster/health 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$ES_HEALTH" ]; then
    echo -e "${RED}ERROR: Cannot reach Elasticsearch. Is the LME service running?${NC}"
    echo -e "${YELLOW}Try: sudo systemctl status lme${NC}"
    exit 1
fi

NODE_COUNT=$(echo "$ES_HEALTH" | grep -o '"number_of_nodes":[0-9]*' | cut -d: -f2)
if [ "$NODE_COUNT" != "1" ]; then
    echo -e "${RED}ERROR: This installation already has $NODE_COUNT nodes.${NC}"
    echo -e "${RED}This script is intended for single-node installations only.${NC}"
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
ANSIBLE_CMD="ansible-playbook -i $INVENTORY_FILE $PLAYBOOK"
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
    echo -e "  source /opt/lme/scripts/extract_secrets.sh -q"
    echo -e "  curl -sk -u elastic:\$lme_elastic_password https://localhost:9200/_cluster/health?pretty"
    echo -e "  curl -sk -u elastic:\$lme_elastic_password https://localhost:9200/_cat/nodes?v"
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
