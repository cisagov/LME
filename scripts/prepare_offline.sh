#!/bin/bash

# prepare_offline.sh - Prepare resources for offline LME installation
# This script downloads all necessary resources for installing LME on systems without internet access
# Supports: Ubuntu 24.04 and RedHat-based systems (RHEL 9, AlmaLinux, Rocky Linux)

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
LME_DIR="$(dirname "$SCRIPT_DIR")"

# Configuration
OUTPUT_DIR="${LME_DIR}/offline_resources"
CONTAINERS_FILE="${LME_DIR}/config/containers.txt"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME=$ID
        OS_VERSION=$VERSION_ID
        OS_VERSION_MAJOR=$(echo $VERSION_ID | cut -d. -f1)
    else
        echo -e "${RED}Cannot detect OS. /etc/os-release not found.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Detected OS: $OS_NAME $OS_VERSION${NC}"
}

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    local missing_tools=()
    
    # Check for required tools
    for tool in wget curl tar gzip; do
        if ! command -v $tool &> /dev/null; then
            missing_tools+=($tool)
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        echo -e "${RED}Missing required tools: ${missing_tools[*]}${NC}"
        echo -e "${YELLOW}Please install them first.${NC}"
        exit 1
    fi
    
    # Check for podman (needed to save container images)
    if ! command -v podman &> /dev/null; then
        echo -e "${YELLOW}Podman not found. Installing podman temporarily to pull container images...${NC}"
        install_podman_temporarily
    fi
    
    echo -e "${GREEN}✓ All prerequisites met${NC}"
}

# Install podman temporarily for pulling images
install_podman_temporarily() {
    case $OS_NAME in
        ubuntu|debian)
            sudo apt-get update
            sudo apt-get install -y podman
            ;;
        rhel|almalinux|rocky|centos)
            sudo dnf install -y podman
            ;;
        *)
            echo -e "${RED}Unsupported OS for automatic podman installation: $OS_NAME${NC}"
            echo -e "${YELLOW}Please install podman manually and run this script again.${NC}"
            exit 1
            ;;
    esac
}

# Create output directory structure
create_output_dirs() {
    echo -e "${YELLOW}Creating output directory structure...${NC}"
    mkdir -p "$OUTPUT_DIR"/{containers,packages,nix,agents,cve,scripts}
    echo -e "${GREEN}✓ Output directories created${NC}"
}

# Download container images
download_containers() {
    echo -e "${YELLOW}Downloading and saving container images...${NC}"

    if [ ! -f "$CONTAINERS_FILE" ]; then
        echo -e "${RED}Container list file not found: $CONTAINERS_FILE${NC}"
        exit 1
    fi

    # Read containers from file (package-registry should already be in containers.txt)
    local containers=$(cat "$CONTAINERS_FILE" | grep -v '^#' | grep -v '^$')

    for container in $containers; do
        echo -e "${YELLOW}Processing: $container${NC}"

        # Extract image name for filename (replace / and : with _)
        image_name=$(echo "$container" | sed 's|.*/||' | sed 's/:/_/g')
        output_file="$OUTPUT_DIR/containers/${image_name}.tar"

        # Skip if tar file already exists
        if [ -f "$output_file" ]; then
            echo -e "${GREEN}  ✓ Tar file already exists: $(basename $output_file), skipping${NC}"
            continue
        fi

        # Check if image already exists in podman
        if podman image exists "$container" 2>/dev/null; then
            echo -e "${GREEN}  ✓ Image already exists: $container${NC}"
        else
            echo -e "${YELLOW}  Pulling image...${NC}"
            if podman pull "$container"; then
                echo -e "${GREEN}  ✓ Successfully pulled $container${NC}"
            else
                echo -e "${RED}  ✗ Failed to pull $container${NC}"
                exit 1
            fi
        fi

        # Save the image as individual tar file
        echo -e "${YELLOW}  Saving image to $output_file...${NC}"
        if podman save -o "$output_file" "$container"; then
            echo -e "${GREEN}  ✓ Successfully saved to $(basename $output_file)${NC}"
        else
            echo -e "${RED}  ✗ Failed to save $container${NC}"
            exit 1
        fi
    done

    echo -e "${GREEN}✓ All container images downloaded and saved${NC}"
}

# Download system packages for Ubuntu 24.04
download_ubuntu_packages() {
    echo -e "${YELLOW}Downloading Ubuntu 24.04 packages...${NC}"
    
    local packages=(
        "wget" "gnupg2" "sudo" "git" "expect"
        "curl" "apt-transport-https" "ca-certificates" "gnupg"
        "lsb-release" "software-properties-common" "openssh-client"
        "fuse-overlayfs" "build-essential" "python3-pip" "python3-pexpect"
        "python3.12" "python3.12-venv" "python3.12-dev"
        "nix-bin" "nix-setup-systemd"
    )
    
    cd "$OUTPUT_DIR/packages"
    
    # Download packages and their dependencies
    for pkg in "${packages[@]}"; do
        echo -e "${YELLOW}Downloading $pkg and dependencies...${NC}"
        apt-get download $(apt-cache depends --recurse --no-recommends --no-suggests \
            --no-conflicts --no-breaks --no-replaces --no-enhances \
            $pkg | grep "^\w" | sort -u) 2>/dev/null || true
    done
    
    echo -e "${GREEN}✓ Ubuntu packages downloaded to $OUTPUT_DIR/packages/${NC}"
}

# Download system packages for RedHat
download_redhat_packages() {
    echo -e "${YELLOW}Downloading RedHat packages...${NC}"
    
    local packages=(
        "wget" "gnupg2" "sudo" "git" "expect"
        "ca-certificates" "openssh-clients" "dnf-plugins-core"
        "fuse-overlayfs" "python3-pip" "python3-pexpect"
        "glibc-langpack-en" "xz" "python3.11" "python3.11-pip" "python3.11-devel"
    )
    
    cd "$OUTPUT_DIR/packages"
    
    # Download packages and their dependencies
    for pkg in "${packages[@]}"; do
        echo -e "${YELLOW}Downloading $pkg and dependencies...${NC}"
        dnf download --resolve --alldeps $pkg 2>/dev/null || true
    done
    
    echo -e "${GREEN}✓ RedHat packages downloaded to $OUTPUT_DIR/packages/${NC}"
}

# Download Nix packages
download_nix_packages() {
    echo -e "${YELLOW}Downloading Nix packages...${NC}"
    
    # Download Nix installer
    wget -O "$OUTPUT_DIR/nix/install-nix.sh" https://nixos.org/nix/install
    chmod +x "$OUTPUT_DIR/nix/install-nix.sh"
    
    # Check if Nix is installed
    if command -v nix-env &> /dev/null; then
        echo -e "${YELLOW}Downloading podman and docker-compose via Nix...${NC}"
        
        # Install packages to Nix store
        nix-env -iA nixpkgs.podman nixpkgs.docker-compose
        
        # Export the closure (all dependencies)
        nix-store --export $(nix-store -qR $(which podman)) > "$OUTPUT_DIR/nix/podman-closure.nar"
        
        echo -e "${GREEN}✓ Nix packages exported${NC}"
    else
        echo -e "${YELLOW}Nix not installed. Skipping Nix package download.${NC}"
        echo -e "${YELLOW}Note: Nix packages will be installed from the downloaded installer during offline installation.${NC}"
    fi
}

# Download agent installers
download_agents() {
    echo -e "${YELLOW}Downloading agent installers...${NC}"
    
    # Read versions from environment file
    if [ -f "${LME_DIR}/config/example.env" ]; then
        STACK_VERSION=$(grep "^STACK_VERSION=" "${LME_DIR}/config/example.env" | cut -d'=' -f2 | tr -d '"')
        WAZUH_VERSION=$(grep "^WAZUH_VERSION=" "${LME_DIR}/config/example.env" | cut -d'=' -f2 | tr -d '"')
    else
        STACK_VERSION="8.18.3"
        WAZUH_VERSION="4.9.1"
    fi
    
    echo -e "${YELLOW}Downloading Elastic Agent $STACK_VERSION...${NC}"
    
    # Elastic Agent downloads
    wget -O "$OUTPUT_DIR/agents/elastic-agent-${STACK_VERSION}-windows-x86_64.zip" \
        "https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-${STACK_VERSION}-windows-x86_64.zip" || true
    
    wget -O "$OUTPUT_DIR/agents/elastic-agent-${STACK_VERSION}-amd64.deb" \
        "https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-${STACK_VERSION}-amd64.deb" || true
    
    wget -O "$OUTPUT_DIR/agents/elastic-agent-${STACK_VERSION}-x86_64.rpm" \
        "https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-${STACK_VERSION}-x86_64.rpm" || true
    
    wget -O "$OUTPUT_DIR/agents/elastic-agent-${STACK_VERSION}-linux-x86_64.tar.gz" \
        "https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-${STACK_VERSION}-linux-x86_64.tar.gz" || true
    
    echo -e "${YELLOW}Downloading Wazuh Agent $WAZUH_VERSION...${NC}"
    
    # Wazuh Agent downloads
    wget -O "$OUTPUT_DIR/agents/wazuh-agent-${WAZUH_VERSION}-windows-amd64.msi" \
        "https://packages.wazuh.com/4.x/windows/wazuh-agent-${WAZUH_VERSION}-1.msi" || true
    
    wget -O "$OUTPUT_DIR/agents/wazuh-agent_${WAZUH_VERSION}-1_amd64.deb" \
        "https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_${WAZUH_VERSION}-1_amd64.deb" || true
    
    wget -O "$OUTPUT_DIR/agents/wazuh-agent-${WAZUH_VERSION}-1.x86_64.rpm" \
        "https://packages.wazuh.com/4.x/yum/wazuh-agent-${WAZUH_VERSION}-1.x86_64.rpm" || true
    
    echo -e "${GREEN}✓ Agent installers downloaded${NC}"
}

# Download CVE database
download_cve_database() {
    echo -e "${YELLOW}Downloading CVE database for offline vulnerability detection...${NC}"
    
    wget -O "$OUTPUT_DIR/cve/cves.zip" \
        "https://cti.wazuh.com/api/v1/catalog/contexts/vd_1.0.0/consumers/vd_4.10.0/cves.zip" || true
    
    if [ -f "$OUTPUT_DIR/cve/cves.zip" ]; then
        echo -e "${GREEN}✓ CVE database downloaded${NC}"
    else
        echo -e "${YELLOW}⚠ CVE database download failed (non-critical)${NC}"
    fi
}

# Generate installation scripts
generate_install_scripts() {
    echo -e "${YELLOW}Generating installation scripts...${NC}"
    
    # Generate package installation script for Ubuntu
    cat > "$OUTPUT_DIR/scripts/install_packages_ubuntu.sh" << 'EOF'
#!/bin/bash
set -e
echo "Installing packages from offline cache..."
cd "$(dirname "$0")/../packages"
sudo dpkg -i *.deb || sudo apt-get install -f -y
echo "✓ Packages installed"
EOF
    
    # Generate package installation script for RedHat
    cat > "$OUTPUT_DIR/scripts/install_packages_redhat.sh" << 'EOF'
#!/bin/bash
set -e
echo "Installing packages from offline cache..."
cd "$(dirname "$0")/../packages"
sudo dnf install -y *.rpm
echo "✓ Packages installed"
EOF
    
    # Generate container load script
    cat > "$OUTPUT_DIR/scripts/load_containers.sh" << 'EOF'
#!/bin/bash
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(dirname "$0")"
CONTAINERS_DIR="$SCRIPT_DIR/../containers"

echo -e "${YELLOW}Loading and tagging container images...${NC}"

if [ ! -d "$CONTAINERS_DIR" ]; then
    echo -e "${RED}✗ Containers directory not found: $CONTAINERS_DIR${NC}"
    exit 1
fi

# Ensure podman is in PATH
export PATH=$PATH:/nix/var/nix/profiles/default/bin

# Load and tag each container image
for tar_file in "$CONTAINERS_DIR"/*.tar; do
    if [ -f "$tar_file" ]; then
        echo -e "${YELLOW}Loading $(basename "$tar_file")...${NC}"

        # Load the image and capture the output to get the actual image name
        LOAD_OUTPUT=$(sudo podman load -i "$tar_file" 2>&1)
        echo "$LOAD_OUTPUT"

        # Extract the loaded image name from output (format: "Loaded image: docker.elastic.co/...")
        LOADED_IMAGE=$(echo "$LOAD_OUTPUT" | grep -oP 'Loaded image: \K.*' || echo "$LOAD_OUTPUT" | grep -oP 'Getting image source signatures.*' && sudo podman images --format "{{.Repository}}:{{.Tag}}" | head -1)

        if [ -z "$LOADED_IMAGE" ]; then
            echo -e "${RED}✗ Failed to determine loaded image name${NC}"
            continue
        fi

        echo -e "${GREEN}  ✓ Loaded: $LOADED_IMAGE${NC}"

        # Determine the target tag based on the image name
        # Extract the last component before the version (e.g., elasticsearch, kibana, etc.)
        IMAGE_COMPONENT=$(echo "$LOADED_IMAGE" | awk -F'/' '{print $NF}' | cut -d':' -f1)
        TARGET_TAG="localhost/${IMAGE_COMPONENT}:LME_LATEST"

        echo -e "${YELLOW}  Tagging as: $TARGET_TAG${NC}"

        if sudo podman tag "$LOADED_IMAGE" "$TARGET_TAG"; then
            echo -e "${GREEN}  ✓ Tagged successfully${NC}"

            # Verify the tag
            if sudo podman image exists "$TARGET_TAG"; then
                # Get image IDs to verify they match
                SOURCE_ID=$(sudo podman images --format "{{.ID}}" "$LOADED_IMAGE" | head -1)
                TARGET_ID=$(sudo podman images --format "{{.ID}}" "$TARGET_TAG" | head -1)

                if [ "$SOURCE_ID" = "$TARGET_ID" ]; then
                    echo -e "${GREEN}  ✓ Verified: Image IDs match ($SOURCE_ID)${NC}"
                else
                    echo -e "${RED}  ✗ Warning: Image ID mismatch! Source=$SOURCE_ID Target=$TARGET_ID${NC}"
                fi
            else
                echo -e "${RED}  ✗ Tag verification failed${NC}"
            fi
        else
            echo -e "${RED}  ✗ Failed to tag image${NC}"
        fi

        echo ""
    fi
done

echo -e "${GREEN}✓ Container images loaded and tagged${NC}"
echo -e "${YELLOW}Verify with: sudo podman images${NC}"
EOF
    
    chmod +x "$OUTPUT_DIR/scripts"/*.sh
    
    echo -e "${GREEN}✓ Installation scripts generated${NC}"
}

# Create offline archive
create_offline_archive() {
    echo -e "${YELLOW}Creating offline installation archive...${NC}"
    
    cd "$LME_DIR"
    tar -czf "lme-offline-${OS_NAME}-${OS_VERSION}-${TIMESTAMP}.tar.gz" \
        --exclude='.git' \
        --exclude='*.tar.gz' \
        offline_resources/
    
    echo -e "${GREEN}✓ Offline archive created: lme-offline-${OS_NAME}-${OS_VERSION}-${TIMESTAMP}.tar.gz${NC}"
    echo -e "${YELLOW}Archive size: $(du -h "lme-offline-${OS_NAME}-${OS_VERSION}-${TIMESTAMP}.tar.gz" | cut -f1)${NC}"
}

# Main execution
main() {
    echo "========================================"
    echo "  LME Offline Installation Preparation"
    echo "========================================"
    echo
    
    detect_os
    check_prerequisites
    create_output_dirs
    download_containers
    
    case $OS_NAME in
        ubuntu|debian)
            download_ubuntu_packages
            ;;
        rhel|almalinux|rocky|centos)
            download_redhat_packages
            ;;
        *)
            echo -e "${RED}Unsupported OS: $OS_NAME${NC}"
            exit 1
            ;;
    esac
    
    download_nix_packages
    download_agents
    download_cve_database
    generate_install_scripts
    create_offline_archive
    
    echo
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Offline preparation complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    echo -e "${YELLOW}Next steps:${NC}"
    echo -e "1. Transfer the archive to your offline system"
    echo -e "2. Extract: tar -xzf lme-offline-*.tar.gz"
    echo -e "3. Run: ./install.sh --offline"
    echo
}

main "$@"

