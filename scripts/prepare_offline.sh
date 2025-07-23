#!/bin/bash

# LME Offline Preparation Script
# This script helps prepare resources for offline LME installation

# Colors for better readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
LME_ROOT="$(dirname "$SCRIPT_DIR")"
CONTAINERS_FILE="$LME_ROOT/config/containers.txt"
OUTPUT_DIR="$LME_ROOT/offline_resources"

# Print usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "This script prepares resources for offline LME installation by:"
    echo "- Installing all prerequisites including Ansible"
    echo "- Downloading and saving container images"
    echo "- Creating a package list for manual download"
    echo "- Generating offline installation instructions"
    echo
    echo "OPTIONS:"
    echo "  -o, --output DIR              Output directory for offline resources (default: ./offline_resources)"
    echo "  -h, --help                    Show this help message"
    echo
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            OUTPUT_DIR="$2"
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

# Check if running with internet access
check_internet() {
    echo -e "${YELLOW}Checking internet connectivity...${NC}"
    if curl -s --connect-timeout 5 https://www.google.com > /dev/null; then
        echo -e "${GREEN}✓ Internet connection available${NC}"
        return 0
    else
        echo -e "${RED}✗ No internet connection detected${NC}"
        echo -e "${RED}This script requires internet access to download resources${NC}"
        exit 1
    fi
}

# Install all prerequisites needed for LME
install_prerequisites() {
    echo -e "${YELLOW}Installing all prerequisites...${NC}"

    # Update system
    sudo apt-get update
    sudo apt-get upgrade -y

    # Install common packages
    sudo apt-get install -y curl wget gnupg2 sudo git openssh-client expect

    # Install Debian/Ubuntu specific packages
    sudo apt-get install -y apt-transport-https ca-certificates gnupg lsb-release software-properties-common fuse-overlayfs build-essential python3-pip python3-pexpect locales uidmap

    # Install Ansible properly
    echo -e "${YELLOW}Installing Ansible...${NC}"
    sudo apt-get install -y software-properties-common
    sudo add-apt-repository --yes --update ppa:ansible/ansible
    sudo apt-get update
    sudo apt-get install -y ansible

    # Verify Ansible installation
    if command -v ansible &> /dev/null; then
        echo -e "${GREEN}✓ Ansible installed successfully: $(ansible --version | head -n1)${NC}"
    else
        echo -e "${RED}✗ Failed to install Ansible${NC}"
        exit 1
    fi

    # Install Nix properly
    echo -e "${YELLOW}Installing Nix...${NC}"
    sudo apt-get install -y nix-bin nix-setup-systemd
    sudo systemctl enable nix-daemon
    sudo systemctl start nix-daemon
    
    # Add user to nix-users group
    sudo usermod -a -G nix-users $USER
    
    # Wait a moment for the service to be ready
    sleep 5

    # Set up nix channels as root
    echo -e "${YELLOW}Setting up Nix channels...${NC}"
    sudo nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs
    sudo nix-channel --update

    # Install Podman via Nix as root
    echo -e "${YELLOW}Installing Podman via Nix...${NC}"
    sudo nix-env -iA nixpkgs.podman

    # Create symlink and add to PATH
    sudo ln -sf /nix/var/nix/profiles/default/bin/podman /usr/local/bin/podman
    export PATH=$PATH:/nix/var/nix/profiles/default/bin

    # Set up containers directories and policy (matching playbook setup)
    mkdir -p ~/.config/containers
    sudo mkdir -p /etc/containers

    # Create policy.json file (matching what the playbook does)
    sudo tee /etc/containers/policy.json > /dev/null << 'EOF'
{
    "default": [
        {
            "type": "insecureAcceptAnything"
        }
    ]
}
EOF

    # Set up storage.conf (matching playbook setup)
    sudo tee /etc/containers/storage.conf > /dev/null << 'EOF'
[storage]
driver = "overlay"
runroot = "/run/containers/storage"
graphroot = "/var/lib/containers/storage"
[storage.options.overlay]
mount_program = "/usr/bin/fuse-overlayfs"
EOF

    # Set up subuid/subgid (matching playbook setup)
    echo "containers:165536:65536" | sudo tee -a /etc/subuid
    echo "containers:165536:65536" | sudo tee -a /etc/subgid

    echo -e "${GREEN}✓ All prerequisites installed${NC}"
}

# Check if podman is available
check_podman() {
    echo -e "${YELLOW}Checking for Podman...${NC}"
    if command -v podman &> /dev/null || [ -x "/nix/var/nix/profiles/default/bin/podman" ] || [ -x "/usr/local/bin/podman" ]; then
        echo -e "${GREEN}✓ Podman is available${NC}"
        export PATH=$PATH:/nix/var/nix/profiles/default/bin
        return 0
    else
        echo -e "${RED}✗ Podman is not installed${NC}"
        echo -e "${RED}Please install Podman to download container images${NC}"
        exit 1
    fi
}

# Create output directory
create_output_dir() {
    echo -e "${YELLOW}Creating output directory: $OUTPUT_DIR${NC}"
    mkdir -p "$OUTPUT_DIR/container_images"
    mkdir -p "$OUTPUT_DIR/packages"
    mkdir -p "$OUTPUT_DIR/docs"
}

# Download and save container images
download_containers() {
    echo -e "${YELLOW}Downloading and saving container images...${NC}"

    if [ ! -f "$CONTAINERS_FILE" ]; then
        echo -e "${RED}✗ Containers file not found: $CONTAINERS_FILE${NC}"
        exit 1
    fi

    while IFS= read -r container; do
        if [ -n "$container" ] && [[ ! "$container" =~ ^[[:space:]]*# ]]; then
            echo -e "${YELLOW}Processing: $container${NC}"

            # Extract image name for filename
            image_name=$(echo "$container" | sed 's|.*/||' | sed 's/:/_/g')
            output_file="$OUTPUT_DIR/container_images/${image_name}.tar"

            # Pull the image with debugging
            echo -e "${YELLOW}  Pulling image...${NC}"
            echo -e "${YELLOW}  Debug: Using podman command: $(which podman)${NC}"
            echo -e "${YELLOW}  Debug: PATH: $PATH${NC}"
            echo -e "${YELLOW}  Debug: User: $(whoami)${NC}"
            echo -e "${YELLOW}  Debug: Groups: $(groups)${NC}"

            if sudo podman pull "$container"; then
                echo -e "${GREEN}  ✓ Successfully pulled $container${NC}"

                # Save the image
                echo -e "${YELLOW}  Saving image to $output_file...${NC}"
                if sudo podman save -o "$output_file" "$container"; then
                    echo -e "${GREEN}  ✓ Successfully saved to $output_file${NC}"
                    # Make the file readable by the user
                    sudo chown $USER:$USER "$output_file"
                else
                    echo -e "${RED}  ✗ Failed to save $container${NC}"
                fi
            else
                echo -e "${RED}  ✗ Failed to pull $container${NC}"
            fi
            echo
        fi
    done < "$CONTAINERS_FILE"
}

# Generate package lists
generate_package_lists() {
    echo -e "${YELLOW}Generating package lists...${NC}"

    cat > "$OUTPUT_DIR/packages/common_packages.txt" << EOF
# Common packages required for LME installation
curl
wget
gnupg2
sudo
git
openssh-client
expect
EOF

    cat > "$OUTPUT_DIR/packages/debian_ubuntu_packages.txt" << EOF
# Debian/Ubuntu specific packages
apt-transport-https
ca-certificates
gnupg
lsb-release
software-properties-common
fuse-overlayfs
build-essential
python3-pip
python3-pexpect
locales
nix-bin
nix-setup-systemd
uidmap
ansible
EOF

    # Generate a script to install packages offline
    cat > "$OUTPUT_DIR/packages/install_packages_offline.sh" << 'EOF'
#!/bin/bash

# Script to install packages offline on the target system
# Run this before running LME installation

echo "Installing required packages for LME offline installation..."

# Common packages
sudo apt-get update
sudo apt-get install -y curl wget gnupg2 sudo git openssh-client expect

# Debian/Ubuntu specific packages  
sudo apt-get install -y apt-transport-https ca-certificates gnupg lsb-release software-properties-common fuse-overlayfs build-essential python3-pip python3-pexpect locales uidmap

# Install Ansible (this is the critical missing piece!)
sudo apt-get install -y software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt-get update
sudo apt-get install -y ansible

# Install Nix
sudo apt-get install -y nix-bin nix-setup-systemd
sudo systemctl enable nix-daemon
sudo systemctl start nix-daemon

echo "Package installation complete!"
echo "Next: Run ./load_containers.sh to load container images"
EOF

    chmod +x "$OUTPUT_DIR/packages/install_packages_offline.sh"

    echo -e "${GREEN}✓ Package lists and installation script created in $OUTPUT_DIR/packages/${NC}"
}

# Generate load script for target system
generate_load_script() {
    echo -e "${YELLOW}Generating container load script...${NC}"

    cat > "$OUTPUT_DIR/load_containers.sh" << 'EOF'
#!/bin/bash

# Container Loading Script for Offline LME Installation
# Run this script on the target system to load container images

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
IMAGES_DIR="$SCRIPT_DIR/container_images"

echo -e "${YELLOW}Loading container images for offline LME installation...${NC}"

if [ ! -d "$IMAGES_DIR" ]; then
    echo -e "${RED}✗ Container images directory not found: $IMAGES_DIR${NC}"
    exit 1
fi

# Check if podman is available (try multiple paths)
PODMAN_CMD=""
if command -v podman &> /dev/null; then
    PODMAN_CMD="podman"
elif [ -x "/nix/var/nix/profiles/default/bin/podman" ]; then
    PODMAN_CMD="/nix/var/nix/profiles/default/bin/podman"
elif [ -x "/usr/local/bin/podman" ]; then
    PODMAN_CMD="/usr/local/bin/podman"
else
    echo -e "${RED}✗ Podman is not installed or not found${NC}"
    echo -e "${YELLOW}Please install Podman first or run the package installation script${NC}"
    exit 1
fi

echo -e "${GREEN}Using Podman from: $PODMAN_CMD${NC}"

# Load all tar files in the images directory
for tar_file in "$IMAGES_DIR"/*.tar; do
    if [ -f "$tar_file" ]; then
        echo -e "${YELLOW}Loading $(basename "$tar_file")...${NC}"
        if sudo $PODMAN_CMD load -i "$tar_file"; then
            echo -e "${GREEN}✓ Successfully loaded $(basename "$tar_file")${NC}"
        else
            echo -e "${RED}✗ Failed to load $(basename "$tar_file")${NC}"
        fi
    fi
done

echo -e "${GREEN}Container loading complete!${NC}"
echo -e "${YELLOW}Verify loaded images with: $PODMAN_CMD images${NC}"
EOF

    chmod +x "$OUTPUT_DIR/load_containers.sh"
    echo -e "${GREEN}✓ Container load script created: $OUTPUT_DIR/load_containers.sh${NC}"
}

# Generate installation instructions
generate_instructions() {
    echo -e "${YELLOW}Generating offline installation instructions...${NC}"

    cat > "$OUTPUT_DIR/docs/OFFLINE_INSTALLATION_INSTRUCTIONS.txt" << EOF
LME Offline Installation Instructions
====================================

This directory contains all resources needed for offline LME installation.

Directory Structure:
- container_images/     : Container image tar files
- packages/            : Package lists and installation scripts
- docs/               : Documentation
- load_containers.sh  : Script to load container images

Steps for Offline Installation:
==============================

1. Transfer this entire directory to the target system

2. Install required system packages:
   cd packages/
   sudo ./install_packages_offline.sh

3. Load container images:
   cd ../
   ./load_containers.sh

4. Verify images are loaded:
   podman images

5. Run LME installation in offline mode:
   ./install.sh --offline

Alternative Ansible command:
   ansible-playbook ansible/site.yml --extra-vars '{"offline_mode": true}'

CRITICAL NOTES:
===============

- The install_packages_offline.sh script INCLUDES Ansible installation
- This was the missing piece in the original preparation
- Ansible is required before running LME installation
- All packages will be installed via apt (requires internet on prep system)

Troubleshooting:
===============

- Ensure all packages from packages/ directory are installed
- Verify Ansible is installed: ansible --version
- Verify all container images are loaded with 'podman images'
- Check that Nix is properly configured if using Nix-based installation
- Review OFFLINE_INSTALLATION.md for detailed troubleshooting

Security Notes:
==============

- HIBP password checks are skipped in offline mode
- Use strong, unique passwords (minimum 12 characters)
- Implement proper network security measures
- Apply security updates when internet access becomes available
EOF

    echo -e "${GREEN}✓ Installation instructions created: $OUTPUT_DIR/docs/OFFLINE_INSTALLATION_INSTRUCTIONS.txt${NC}"
}

# Main execution
main() {
    echo -e "${GREEN}LME Offline Preparation Script${NC}"
    echo -e "${GREEN}==============================${NC}"
    echo

    check_internet
    install_prerequisites
    check_podman
    create_output_dir
    download_containers
    generate_package_lists
    generate_load_script
    generate_instructions

    echo -e "${GREEN}✓ Offline preparation complete!${NC}"
    echo -e "${YELLOW}Resources saved to: $OUTPUT_DIR${NC}"
    echo
    echo -e "${GREEN}IMPORTANT: Ansible has been installed on this system!${NC}" 
    echo -e "${GREEN}The offline package installation script will install Ansible on the target system.${NC}"
    echo
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Transfer the $OUTPUT_DIR directory to your target system"
    echo "2. On target system: cd $OUTPUT_DIR/packages && sudo ./install_packages_offline.sh"
    echo "3. On target system: cd .. && ./load_containers.sh"
    echo "4. Run LME installation with --offline flag"
    echo
    echo -e "${YELLOW}For detailed instructions, see:${NC}"
    echo "- $OUTPUT_DIR/docs/OFFLINE_INSTALLATION_INSTRUCTIONS.txt"
}

# Run main function
main
