#!/bin/bash

# LME Offline Archive Validation Script
# This script validates that an offline archive contains all required resources

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
LME_DIR="$(dirname "$SCRIPT_DIR")"

# Print usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "This script validates that an offline LME archive contains all required resources."
    echo
    echo "OPTIONS:"
    echo "  -a, --archive PATH            Path to offline archive (lme-offline-*.tar.gz)"
    echo "  -d, --directory PATH          Path to extracted offline resources directory"
    echo "  -h, --help                    Show this help message"
    echo
    echo "Examples:"
    echo "  $0 -a lme-offline-20241224-123456.tar.gz"
    echo "  $0 -d ./offline_resources"
    echo
    exit 1
}

# Parse command line arguments
ARCHIVE_PATH=""
OFFLINE_DIR=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--archive)
            ARCHIVE_PATH="$2"
            shift 2
            ;;
        -d|--directory)
            OFFLINE_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Error: Unknown option: $1${NC}"
            usage
            ;;
    esac
done

# Validation counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Function to check if a file/directory exists
check_resource() {
    local resource_path="$1"
    local description="$2"
    local is_required="${3:-true}"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [ -e "$resource_path" ]; then
        echo -e "${GREEN}✓ $description${NC}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        if [ "$is_required" = "true" ]; then
            echo -e "${RED}✗ $description${NC}"
            echo -e "${RED}  Missing: $resource_path${NC}"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        else
            echo -e "${YELLOW}⚠ $description (optional)${NC}"
            echo -e "${YELLOW}  Missing: $resource_path${NC}"
        fi
        return 1
    fi
}

# Function to validate container images
validate_container_images() {
    local images_dir="$1"
    echo -e "${YELLOW}Validating container images...${NC}"
    
    # Required container images (from config/containers.txt)
    local required_images=(
        "elasticsearch_8.18.3.tar"
        "elastic-agent_8.18.3.tar"
        "kibana_8.18.3.tar"
        "wazuh-manager_4.9.1.tar"
        "elastalert2_2.20.0.tar"
    )
    
    for image in "${required_images[@]}"; do
        check_resource "$images_dir/$image" "Container image: $image"
    done
}

# Function to validate Nix packages
validate_nix_packages() {
    local nix_dir="$1"
    echo -e "${YELLOW}Validating Nix packages...${NC}"
    
    check_resource "$nix_dir/podman-closure.nar" "Podman Nix closure"
    check_resource "$nix_dir/podman-store-path.txt" "Podman store path file"
}

# Function to validate system packages
validate_system_packages() {
    local packages_dir="$1"
    echo -e "${YELLOW}Validating system packages...${NC}"
    
    check_resource "$packages_dir/debs" "Ubuntu/Debian packages directory" "false"
    check_resource "$packages_dir/rpms" "RedHat/CentOS packages directory" "false"
    check_resource "$packages_dir/install_packages_offline.sh" "Package installation script"
}

# Function to validate other resources
validate_other_resources() {
    local offline_dir="$1"
    echo -e "${YELLOW}Validating other resources...${NC}"
    
    check_resource "$offline_dir/load_containers.sh" "Container loading script"
    check_resource "$offline_dir/agents" "Agent installers directory" "false"
    check_resource "$offline_dir/cve" "CVE database directory" "false"
    check_resource "$offline_dir/docs" "Documentation directory" "false"
    check_resource "$offline_dir/nix/install-nix.sh" "Nix installer script" "false"
}

# Function to validate LME directory structure
validate_lme_structure() {
    local lme_dir="$1"
    echo -e "${YELLOW}Validating LME directory structure...${NC}"

    check_resource "$lme_dir/config" "Config directory"
    check_resource "$lme_dir/config/example.env" "Example environment file"
    check_resource "$lme_dir/install.sh" "Installation script"
    check_resource "$lme_dir/ansible" "Ansible directory"
    check_resource "$lme_dir/scripts" "Scripts directory"
}

# Main validation function
validate_offline_resources() {
    local base_dir="$1"

    echo -e "${YELLOW}Validating offline resources in: $base_dir${NC}"
    echo

    # Check main structure
    check_resource "$base_dir" "Offline resources directory"
    check_resource "$base_dir/container_images" "Container images directory"
    check_resource "$base_dir/packages" "Packages directory"
    check_resource "$base_dir/packages/nix" "Nix packages directory"

    # Validate specific components
    validate_container_images "$base_dir/container_images"
    validate_nix_packages "$base_dir/packages/nix"
    validate_system_packages "$base_dir/packages"
    validate_other_resources "$base_dir"
}

# Main execution
echo -e "${GREEN}LME Offline Archive Validation${NC}"
echo -e "${GREEN}==============================${NC}"
echo

if [ -n "$ARCHIVE_PATH" ]; then
    # Validate archive file
    if [ ! -f "$ARCHIVE_PATH" ]; then
        echo -e "${RED}✗ Archive file not found: $ARCHIVE_PATH${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Extracting archive for validation...${NC}"
    TEMP_DIR=$(mktemp -d)
    
    if tar -tzf "$ARCHIVE_PATH" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Archive is readable${NC}"
        
        # Extract to temp directory
        tar -xzf "$ARCHIVE_PATH" -C "$TEMP_DIR"
        
        # Find the LME directory in the archive
        LME_EXTRACTED_DIR=$(find "$TEMP_DIR" -name "LME" -type d | head -1)
        if [ -n "$LME_EXTRACTED_DIR" ]; then
            # Validate LME directory structure first
            validate_lme_structure "$LME_EXTRACTED_DIR"
            OFFLINE_DIR="$LME_EXTRACTED_DIR/offline_resources"
        else
            echo -e "${RED}✗ Could not find LME directory in archive${NC}"
            rm -rf "$TEMP_DIR"
            exit 1
        fi
    else
        echo -e "${RED}✗ Archive is corrupted or not a valid tar.gz file${NC}"
        exit 1
    fi
    
elif [ -n "$OFFLINE_DIR" ]; then
    # Validate existing directory
    if [ ! -d "$OFFLINE_DIR" ]; then
        echo -e "${RED}✗ Offline resources directory not found: $OFFLINE_DIR${NC}"
        exit 1
    fi
else
    # Auto-detect offline resources
    if [ -d "$LME_DIR/offline_resources" ]; then
        OFFLINE_DIR="$LME_DIR/offline_resources"
        echo -e "${YELLOW}Auto-detected offline resources: $OFFLINE_DIR${NC}"
    else
        echo -e "${RED}✗ No offline resources found. Use -a or -d options.${NC}"
        usage
    fi
fi

# Run validation
validate_offline_resources "$OFFLINE_DIR"

# Cleanup temp directory if created
if [ -n "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
fi

# Print summary
echo
echo -e "${YELLOW}Validation Summary:${NC}"
echo -e "${GREEN}  Passed: $PASSED_CHECKS${NC}"
echo -e "${RED}  Failed: $FAILED_CHECKS${NC}"
echo -e "${YELLOW}  Total:  $TOTAL_CHECKS${NC}"

if [ $FAILED_CHECKS -eq 0 ]; then
    echo
    echo -e "${GREEN}✓ All validation checks passed!${NC}"
    echo -e "${GREEN}The offline archive appears to be complete and ready for installation.${NC}"
    exit 0
else
    echo
    echo -e "${RED}✗ $FAILED_CHECKS validation check(s) failed!${NC}"
    echo -e "${RED}The offline archive may be incomplete or corrupted.${NC}"
    echo -e "${YELLOW}Please run prepare_offline.sh again to create a complete archive.${NC}"
    exit 1
fi
