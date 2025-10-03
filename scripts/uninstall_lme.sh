#!/bin/bash

# LME Uninstall Script
# This script safely removes all LME components from the system
# Use this to cleanly uninstall LME and start over if needed

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script must be run as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root (use sudo)${NC}" 
   exit 1
fi

# Confirmation prompt
echo -e "${YELLOW}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║                    LME UNINSTALL SCRIPT                        ║${NC}"
echo -e "${YELLOW}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}WARNING: This will completely remove LME from your system!${NC}"
echo ""
echo "This script will remove:"
echo "  • All LME systemd services"
echo "  • All LME containers and images"
echo "  • All LME volumes (INCLUDING ALL DATA)"
echo "  • All LME secrets"
echo "  • LME configuration files"
echo "  • Quadlet files"
echo "  • Systemd generator symlinks"
echo ""
echo -e "${YELLOW}The following will NOT be removed:${NC}"
echo "  • Nix package manager (/nix)"
echo "  • Podman installation"
echo "  • System packages (ansible, etc.)"
echo "  • Sysctl settings"
echo "  • User limits configuration"
echo ""
read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirm

if [ "$confirm" != "yes" ]; then
    echo -e "${GREEN}Uninstall cancelled.${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}Starting LME uninstall...${NC}"
echo ""

# Set PATH to include Nix binaries
export PATH=$PATH:/nix/var/nix/profiles/default/bin

# Step 1: Stop all LME services
echo -e "${YELLOW}[1/12] Stopping all LME services...${NC}"
systemctl stop 'lme*' 2>/dev/null || true
systemctl reset-failed 2>/dev/null || true
echo -e "${GREEN}✓ Services stopped${NC}"

# Step 2: Disable LME service
echo -e "${YELLOW}[2/12] Disabling LME service...${NC}"
systemctl disable lme.service 2>/dev/null || true
echo -e "${GREEN}✓ Service disabled${NC}"

# Step 3: Stop all LME containers
echo -e "${YELLOW}[3/12] Stopping all LME containers...${NC}"
if command -v podman &> /dev/null; then
    # Get list of LME containers with timeout
    LME_CONTAINERS=$(timeout 5 podman ps -a --format "{{.Names}}" 2>/dev/null | grep -E "^lme-" || true)
    if [ -n "$LME_CONTAINERS" ]; then
        echo "$LME_CONTAINERS" | xargs -r timeout 10 podman stop 2>/dev/null || true
        echo -e "${GREEN}✓ Containers stopped${NC}"
    else
        echo -e "${GREEN}✓ No LME containers found${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Podman not found, skipping container stop${NC}"
fi

# Step 4: Remove all LME containers
echo -e "${YELLOW}[4/12] Removing all LME containers...${NC}"
if command -v podman &> /dev/null; then
    if [ -n "$LME_CONTAINERS" ]; then
        echo "$LME_CONTAINERS" | xargs -r timeout 10 podman rm -f 2>/dev/null || true
        echo -e "${GREEN}✓ Containers removed${NC}"
    else
        echo -e "${GREEN}✓ No LME containers to remove${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Podman not found, skipping container removal${NC}"
fi

# Step 5: Remove all LME volumes
echo -e "${YELLOW}[5/12] Removing all LME volumes (THIS DELETES ALL DATA)...${NC}"
if command -v podman &> /dev/null; then
    # List of known LME volumes
    LME_VOLUMES=(
        "lme_esdata01"
        "lme_kibanadata"
        "lme_certs"
        "lme_backups"
        "lme_fleet_data"
        "lme_wazuh_api_configuration"
        "lme_wazuh_etc"
        "lme_wazuh_logs"
        "lme_wazuh_queue"
        "lme_wazuh_var_multigroups"
        "lme_wazuh_integrations"
        "lme_wazuh_active_response"
        "lme_wazuh_agentless"
        "lme_wazuh_wodles"
        "lme_filebeat_etc"
        "lme_filebeat_var"
        "lme_elastalert2_logs"
    )

    for volume in "${LME_VOLUMES[@]}"; do
        if timeout 3 podman volume exists "$volume" 2>/dev/null; then
            timeout 10 podman volume rm "$volume" 2>/dev/null || true
            echo "  Removed: $volume"
        fi
    done

    # Also remove any other volumes starting with lme_
    OTHER_VOLUMES=$(timeout 5 podman volume ls --format "{{.Name}}" 2>/dev/null | grep "^lme_" || true)
    if [ -n "$OTHER_VOLUMES" ]; then
        echo "$OTHER_VOLUMES" | xargs -r timeout 10 podman volume rm 2>/dev/null || true
    fi

    echo -e "${GREEN}✓ Volumes removed${NC}"
else
    echo -e "${YELLOW}⚠ Podman not found, skipping volume removal${NC}"
fi

# Step 6: Remove all LME secrets
echo -e "${YELLOW}[6/12] Removing all LME secrets...${NC}"
if command -v podman &> /dev/null; then
    LME_SECRETS=$(timeout 5 podman secret ls --format "{{.Name}}" 2>/dev/null | grep -E "^(elastic|kibana_system|wazuh|wazuh_api)$" || true)
    if [ -n "$LME_SECRETS" ]; then
        echo "$LME_SECRETS" | xargs -r timeout 10 podman secret rm 2>/dev/null || true
        echo -e "${GREEN}✓ Secrets removed${NC}"
    else
        echo -e "${GREEN}✓ No LME secrets found${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Podman not found, skipping secret removal${NC}"
fi

# Step 7: Remove LME container images
echo -e "${YELLOW}[7/12] Removing LME container images...${NC}"
if command -v podman &> /dev/null; then
    # Remove images tagged with LME_LATEST
    LME_IMAGES=$(timeout 5 podman images --format "{{.Repository}}:{{.Tag}}" 2>/dev/null | grep "LME_LATEST" || true)
    if [ -n "$LME_IMAGES" ]; then
        echo "$LME_IMAGES" | xargs -r timeout 30 podman rmi -f 2>/dev/null || true
    fi

    # Remove specific LME images (localhost tags)
    timeout 30 podman rmi -f \
        localhost/elasticsearch:LME_LATEST \
        localhost/kibana:LME_LATEST \
        localhost/elastic-agent:LME_LATEST \
        localhost/wazuh-manager:LME_LATEST \
        localhost/elastalert2:LME_LATEST \
        localhost/package-registry:LME_LATEST \
        localhost/distribution:LME_LATEST \
        2>/dev/null || true

    # Remove original source images from docker.elastic.co and docker.io
    echo "  Removing source images..."
    timeout 30 podman rmi -f \
        docker.elastic.co/elasticsearch/elasticsearch:8.18.3 \
        docker.elastic.co/kibana/kibana:8.18.3 \
        docker.elastic.co/beats/elastic-agent:8.18.3 \
        docker.io/wazuh/wazuh-manager:4.9.1 \
        docker.io/jertel/elastalert2:2.20.0 \
        docker.elastic.co/package-registry/distribution:8.18.3 \
        2>/dev/null || true

    # Remove any dangling/none images
    echo "  Removing dangling images..."
    DANGLING_IMAGES=$(timeout 5 podman images -f "dangling=true" -q 2>/dev/null || true)
    if [ -n "$DANGLING_IMAGES" ]; then
        echo "$DANGLING_IMAGES" | xargs -r timeout 30 podman rmi -f 2>/dev/null || true
    fi

    # Remove any remaining LME-related images
    echo "  Removing any remaining LME-related images..."
    REMAINING_LME=$(timeout 5 podman images --format "{{.Repository}}:{{.Tag}}" 2>/dev/null | grep -E "(elasticsearch|kibana|elastic-agent|wazuh|elastalert|package-registry|distribution)" || true)
    if [ -n "$REMAINING_LME" ]; then
        echo "$REMAINING_LME" | xargs -r timeout 30 podman rmi -f 2>/dev/null || true
    fi

    echo -e "${GREEN}✓ Images removed${NC}"
else
    echo -e "${YELLOW}⚠ Podman not found, skipping image removal${NC}"
fi

# Step 8: Remove systemd service files
echo -e "${YELLOW}[8/12] Removing systemd service files...${NC}"
rm -f /etc/systemd/system/lme.service
rm -f /etc/systemd/system/lme-*.service
echo -e "${GREEN}✓ Service files removed${NC}"

# Step 9: Remove quadlet files
echo -e "${YELLOW}[9/12] Removing quadlet files...${NC}"
rm -rf /etc/containers/systemd/lme-*
rm -rf /etc/containers/systemd/lme.network
rm -rf /etc/containers/systemd/lme.service
echo -e "${GREEN}✓ Quadlet files removed${NC}"

# Step 10: Remove systemd generator symlinks
echo -e "${YELLOW}[10/12] Removing systemd generator symlinks...${NC}"
rm -f /usr/libexec/podman/quadlet
rm -f /usr/lib/systemd/system-generators/podman-system-generator
echo -e "${GREEN}✓ Generator symlinks removed${NC}"

# Step 11: Remove LME configuration and data
echo -e "${YELLOW}[11/12] Removing LME configuration and data...${NC}"
rm -rf /opt/lme
rm -rf /etc/lme
echo -e "${GREEN}✓ Configuration removed${NC}"

# Step 12: Clean up podman system
echo -e "${YELLOW}[12/13] Cleaning up podman system...${NC}"
if command -v podman &> /dev/null; then
    echo "  Pruning unused images..."
    timeout 30 podman image prune -a -f 2>/dev/null || true
    echo "  Pruning unused volumes..."
    timeout 30 podman volume prune -f 2>/dev/null || true
    echo "  Pruning system..."
    timeout 60 podman system prune -a -f 2>/dev/null || true
    echo -e "${GREEN}✓ Podman system cleaned${NC}"
else
    echo -e "${YELLOW}⚠ Podman not found, skipping system cleanup${NC}"
fi

# Step 13: Reload systemd
echo -e "${YELLOW}[13/13] Reloading systemd daemon...${NC}"
systemctl daemon-reload
echo -e "${GREEN}✓ Systemd reloaded${NC}"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              LME UNINSTALL COMPLETED SUCCESSFULLY              ║${NC}"
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo ""
echo -e "${YELLOW}What was removed:${NC}"
echo "  ✓ All LME systemd services"
echo "  ✓ All LME containers"
echo "  ✓ All LME volumes and data"
echo "  ✓ All LME secrets"
echo "  ✓ All LME container images"
echo "  ✓ LME configuration files"
echo "  ✓ Quadlet files"
echo ""
echo -e "${YELLOW}What remains on the system:${NC}"
echo "  • Nix package manager (/nix)"
echo "  • Podman installation"
echo "  • System packages (ansible, etc.)"
echo "  • Sysctl settings in /etc/sysctl.conf"
echo "  • User limits in /etc/security/limits.conf"
echo "  • User container configs in ~/.config/containers"
echo ""
echo -e "${GREEN}You can now run install.sh again to perform a fresh installation.${NC}"
echo ""

