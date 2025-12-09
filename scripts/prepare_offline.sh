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

# Load environment variables from example.env if it exists
ENV_FILE="$LME_ROOT/config/example.env"
if [ -f "$ENV_FILE" ]; then
    # Source the env file, filtering out comments and empty lines
    set -a  # automatically export all variables
    source <(grep -v '^#' "$ENV_FILE" | grep -v '^$')
    set +a  # stop automatically exporting
fi

# Set default versions if not found in env file
STACK_VERSION=${STACK_VERSION:-"8.18.8"}
WAZUH_VERSION=${WAZUH_VERSION:-"4.9.1"}

# Print usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "This script prepares resources for offline LME installation by:"
    echo "- Downloading and saving container images"
    echo "- Downloading agent installers (Wazuh and Elastic agents)"
    echo "- Downloading CVE database for offline vulnerability detection"
    echo "- Creating a package list for manual download"
    echo "- Generating offline installation instructions"
    echo "- Creating a single archive with all resources"
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

# Force install podman - REQUIRED for this script
install_podman() {
    echo -e "${YELLOW}Installing Podman (REQUIRED)...${NC}"

    # Detect OS and install accordingly
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            echo -e "${YELLOW}Installing Podman via Homebrew...${NC}"
            brew install podman || brew reinstall podman
        else
            echo -e "${RED}Homebrew not found${NC}"
            echo -e "${YELLOW}Installing Homebrew...${NC}"
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            brew install podman
        fi
    elif [[ -f /etc/debian_version ]]; then
        # Debian/Ubuntu
        echo -e "${YELLOW}Installing Podman on Debian/Ubuntu...${NC}"
        sudo apt-get update
        sudo apt-get install -y --reinstall podman
    elif [[ -f /etc/redhat-release ]]; then
        # RHEL/CentOS/Fedora - FORCE reinstall to ensure binary exists
        echo -e "${YELLOW}Installing Podman on RHEL/CentOS/Fedora...${NC}"
        if command -v dnf &> /dev/null; then
            sudo dnf reinstall -y podman || sudo dnf install -y podman
        elif command -v yum &> /dev/null; then
            sudo yum reinstall -y podman || sudo yum install -y podman
        else
            echo -e "${RED}Neither dnf nor yum found - cannot install podman${NC}"
            exit 1
        fi
    else
        echo -e "${RED}Unsupported operating system${NC}"
        exit 1
    fi

    # Refresh PATH and command hash
    export PATH="/usr/bin:/usr/local/bin:/nix/var/nix/profiles/default/bin:$PATH"
    hash -r 2>/dev/null || true

    # Verify installation succeeded
    if ! command -v podman &> /dev/null && [ ! -x "/usr/bin/podman" ] && [ ! -x "/usr/local/bin/podman" ] && [ ! -x "/nix/var/nix/profiles/default/bin/podman" ]; then
        echo -e "${RED}✗ Podman installation failed - binary not found after installation${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ Podman installed successfully${NC}"
}

# Check if podman is available and force install if not
check_podman() {
    echo -e "${YELLOW}Checking for Podman...${NC}"

    # Ensure common podman paths are in PATH
    export PATH="/usr/bin:/usr/local/bin:/nix/var/nix/profiles/default/bin:$PATH"

    # Check if podman binary exists anywhere
    if command -v podman &> /dev/null || [ -x "/nix/var/nix/profiles/default/bin/podman" ] || [ -x "/usr/local/bin/podman" ] || [ -x "/usr/bin/podman" ]; then
        echo -e "${GREEN}✓ Podman is available${NC}"
        TEMP_PODMAN_INSTALLED=false
    else
        echo -e "${YELLOW}Podman not found - installing now...${NC}"
        install_podman
        TEMP_PODMAN_INSTALLED=true
    fi
}

# Install Nix for package preparation
install_nix_for_preparation() {
    echo -e "${YELLOW}Installing Nix for package preparation...${NC}"

    # Download and run the Nix installer
    curl -L https://nixos.org/nix/install | sh

    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Failed to install Nix${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ Nix installation completed${NC}"
}

# Cleanup temporary podman installation
cleanup_temp_podman() {
    if [ "$TEMP_PODMAN_INSTALLED" = true ]; then
        echo -e "${YELLOW}Cleaning up temporary Podman installation...${NC}"

        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS - uninstall via Homebrew
            if command -v brew &> /dev/null; then
                echo -e "${YELLOW}Uninstalling Podman via Homebrew...${NC}"
                brew uninstall podman
            fi
        elif [[ -f /etc/debian_version ]]; then
            # Debian/Ubuntu
            echo -e "${YELLOW}Uninstalling Podman on Debian/Ubuntu...${NC}"
            sudo apt-get remove -y podman
            sudo apt-get autoremove -y
        elif [[ -f /etc/redhat-release ]]; then
            # RHEL/CentOS/Fedora
            echo -e "${YELLOW}Uninstalling Podman on RHEL/CentOS/Fedora...${NC}"
            if command -v dnf &> /dev/null; then
                sudo dnf remove -y podman
            elif command -v yum &> /dev/null; then
                sudo yum remove -y podman
            fi
        fi

        echo -e "${GREEN}✓ Temporary Podman installation cleaned up${NC}"
        echo -e "${YELLOW}Note: LME installation will use Nix-managed Podman${NC}"
    fi

    # Cleanup temporary Nix installation
    if [ "$TEMP_NIX_INSTALLED" = true ]; then
        echo -e "${YELLOW}Cleaning up temporary Nix installation...${NC}"

        # Remove Nix installation
        if [ -d "/nix" ]; then
            sudo rm -rf /nix
        fi

        # Remove Nix profile
        if [ -d "$HOME/.nix-profile" ]; then
            rm -rf "$HOME/.nix-profile"
        fi

        # Remove Nix channels
        if [ -d "$HOME/.nix-channels" ]; then
            rm -f "$HOME/.nix-channels"
        fi

        # Remove Nix defexpr
        if [ -d "$HOME/.nix-defexpr" ]; then
            rm -rf "$HOME/.nix-defexpr"
        fi

        # Remove Nix backup files that can interfere with future installations
        sudo rm -f /etc/bashrc.backup-before-nix 2>/dev/null || true
        sudo rm -f /etc/profile.d/nix.sh.backup-before-nix 2>/dev/null || true
        sudo rm -f /etc/zshrc.backup-before-nix 2>/dev/null || true
        sudo rm -f /etc/bash.bashrc.backup-before-nix 2>/dev/null || true

        echo -e "${GREEN}✓ Temporary Nix installation cleaned up${NC}"
    fi
}

# Create output directory
create_output_dir() {
    echo -e "${YELLOW}Creating output directory: $OUTPUT_DIR${NC}"
    mkdir -p "$OUTPUT_DIR/container_images"
    mkdir -p "$OUTPUT_DIR/packages"
    mkdir -p "$OUTPUT_DIR/agents"
    mkdir -p "$OUTPUT_DIR/cve"
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



# Download file with fallback from wget to curl
download_file() {
    local url="$1"
    local filename="$2"

    if command -v wget >/dev/null 2>&1; then
        wget -q --show-progress "$url" -O "$filename"
    elif command -v curl >/dev/null 2>&1; then
        curl -L --progress-bar "$url" -o "$filename"
    else
        echo -e "${RED}✗ Neither wget nor curl is available${NC}"
        return 1
    fi
}

# Download packages using apt (Ubuntu/Debian)
download_apt_packages() {
    echo -e "${YELLOW}Updating package lists...${NC}"
    sudo apt-get update

    echo -e "${YELLOW}Adding Ansible PPA...${NC}"
    sudo add-apt-repository --yes --update ppa:ansible/ansible
    sudo apt-get update

    echo -e "${YELLOW}Downloading packages...${NC}"
    cd "$OUTPUT_DIR/packages/debs"
    for package in "${PACKAGES[@]}"; do
        echo -e "${YELLOW}  Downloading $package...${NC}"
        apt-get download "$package" 2>/dev/null || echo -e "${RED}  ✗ Failed to download $package${NC}"
    done

    echo -e "${YELLOW}Downloading package dependencies...${NC}"
    for package in "${PACKAGES[@]}"; do
        apt-get download $(apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances "$package" | grep "^\w" | sort -u) 2>/dev/null || true
    done

    cd "$SCRIPT_DIR"
}

# Download packages using dnf (RHEL/CentOS/AlmaLinux/Rocky)
download_dnf_packages() {
    echo -e "${YELLOW}Updating package cache...${NC}"
    sudo dnf makecache

    echo -e "${YELLOW}Installing EPEL repository...${NC}"
    if [ "$OS_ID" = "rhel" ]; then
        # For RHEL, install EPEL from Fedora URL - RHUI repos are working, so use them
        sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm 2>/dev/null || true
    else
        # For other distributions, use standard package
        sudo dnf install -y epel-release
    fi

    echo -e "${YELLOW}Downloading packages...${NC}"
    cd "$OUTPUT_DIR/packages/rpms"

    # Define additional container dependencies that must be included
    CONTAINER_DEPS=(
        "conmon"
        "containers-common"
        "netavark"
        "aardvark-dns"
        "passt"
        "passt-selinux"
        "slirp4netns"
        "shadow-utils"
        "iptables"
        "nftables"
        "crun"
        "runc"
        "fuse-overlayfs"
        "container-selinux"
    )

    # Combine main packages with container dependencies
    ALL_PACKAGES=("${PACKAGES[@]}" "${CONTAINER_DEPS[@]}")
    
    echo -e "${GREEN}Downloading ${#ALL_PACKAGES[@]} packages with all dependencies...${NC}"
    
    # CRITICAL: Use 'dnf download' NOT 'dnf install --downloadonly' because:
    # - 'dnf install --downloadonly' skips packages already installed on this system
    # - 'dnf download --resolve' downloads packages regardless of installation status
    # We need ALL packages for offline installation, even if they're already installed here!
    echo -e "${YELLOW}Using dnf download --resolve for complete dependency resolution...${NC}"
    
    # Try to download all packages with their dependencies
    if sudo dnf download --destdir="$OUTPUT_DIR/packages/rpms" --resolve --alldeps "${ALL_PACKAGES[@]}" 2>&1 | tee /tmp/dnf_download.log; then
        echo -e "${GREEN}✓ Download command completed${NC}"
    else
        echo -e "${YELLOW}⚠ Some packages may have had issues, checking results...${NC}"
    fi

    # List what was downloaded
    RPM_COUNT=$(ls -1 *.rpm 2>/dev/null | wc -l)
    echo -e "${GREEN}✓ Downloaded $RPM_COUNT RPM files total${NC}"

    # Verify critical packages were successfully downloaded
    echo -e "${YELLOW}Verifying critical packages were downloaded...${NC}"
    CRITICAL_PACKAGES=("podman" "ansible" "git" "container-selinux" "conmon" "containers-common" "netavark" "passt" "slirp4netns" "fuse-overlayfs")
    MISSING_PACKAGES=()

    for pkg in "${CRITICAL_PACKAGES[@]}"; do
        if ! ls "$OUTPUT_DIR/packages/rpms/${pkg}"-*.rpm 1> /dev/null 2>&1; then
            MISSING_PACKAGES+=("$pkg")
            echo -e "${RED}✗ Critical package missing: $pkg${NC}"
        else
            PKG_COUNT=$(ls "$OUTPUT_DIR/packages/rpms/${pkg}"-*.rpm 2>/dev/null | wc -l)
            echo -e "${GREEN}✓ Found $pkg ($PKG_COUNT RPM(s))${NC}"
        fi
    done

    if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
        echo -e "${RED}✗ Failed to download critical packages: ${MISSING_PACKAGES[*]}${NC}"
        echo -e "${YELLOW}Attempting to download missing packages individually with full dependency tree...${NC}"
        
        for missing_pkg in "${MISSING_PACKAGES[@]}"; do
            echo -e "${YELLOW}  Downloading $missing_pkg with all dependencies...${NC}"
            # Use 'dnf download' not 'dnf install --downloadonly' to get packages even if installed
            sudo dnf download --destdir="$OUTPUT_DIR/packages/rpms" --resolve --alldeps "$missing_pkg" 2>&1 || true
        done
        
        # Re-verify
        STILL_MISSING=()
        for pkg in "${MISSING_PACKAGES[@]}"; do
            if ! ls "$OUTPUT_DIR/packages/rpms/${pkg}"-*.rpm 1> /dev/null 2>&1; then
                STILL_MISSING+=("$pkg")
            else
                echo -e "${GREEN}✓ Successfully downloaded missing package: $pkg${NC}"
            fi
        done
        
        if [ ${#STILL_MISSING[@]} -gt 0 ]; then
            echo -e "${RED}✗ Still missing critical packages: ${STILL_MISSING[*]}${NC}"
            echo -e "${YELLOW}Please check:${NC}"
            echo -e "${YELLOW}  1. Repository configuration is correct${NC}"
            echo -e "${YELLOW}  2. Package names are valid for your RHEL version${NC}"
            echo -e "${YELLOW}  3. Network connectivity to repositories${NC}"
            exit 1
        fi
    fi

    echo -e "${GREEN}✓ All critical packages verified${NC}"

    cd "$SCRIPT_DIR"
}

# Detect operating system
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID="$ID"
        OS_VERSION_ID="$VERSION_ID"
    elif [ -f /etc/redhat-release ]; then
        OS_ID="rhel"
    elif [ -f /etc/debian_version ]; then
        OS_ID="debian"
    else
        OS_ID="unknown"
    fi

    case "$OS_ID" in
        ubuntu|debian|linuxmint|pop)
            PACKAGE_MANAGER="apt"
            ;;
        rhel|centos|rocky|almalinux|fedora)
            PACKAGE_MANAGER="dnf"
            ;;
        *)
            echo -e "${RED}✗ Unsupported operating system: $OS_ID${NC}"
            echo -e "${YELLOW}Supported systems: Ubuntu, Debian, RHEL, CentOS, Rocky Linux, AlmaLinux, Fedora${NC}"
            exit 1
            ;;
    esac

    echo -e "${GREEN}✓ Detected OS: $OS_ID (using $PACKAGE_MANAGER)${NC}"
}

# Download packages for offline installation
download_packages() {
    echo -e "${YELLOW}Downloading packages for offline installation...${NC}"

    # Detect OS first
    detect_os

    # Create package cache directories
    mkdir -p "$OUTPUT_DIR/packages/debs"
    mkdir -p "$OUTPUT_DIR/packages/rpms"
    mkdir -p "$OUTPUT_DIR/packages/nix"
    mkdir -p "$OUTPUT_DIR/nix"

    # Define OS-specific package lists
    if [ "$PACKAGE_MANAGER" = "apt" ]; then
        PACKAGES=(
            "curl"
            "wget"
            "gnupg2"
            "sudo"
            "git"
            "openssh-client"
            "expect"
            "apt-transport-https"
            "ca-certificates"
            "gnupg"
            "lsb-release"
            "software-properties-common"
            "fuse-overlayfs"
            "build-essential"
            "python3-pip"
            "python3-pexpect"
            "locales"
            "uidmap"
            "ansible"
            "nix-bin"
            "nix-setup-systemd"
        )
    else
        # RHEL/CentOS/AlmaLinux/Rocky packages
        # NOTE: Only include packages NOT already in RHEL 9 base installation
        # Removed packages that are pre-installed: curl, wget, sudo, openssh-clients,
        # ca-certificates, shadow-utils, glibc-langpack-en, xz, bzip2, policycoreutils,
        # selinux-policy, selinux-policy-targeted, libselinux-utils
        # Also removed development tools (gcc, gcc-c++, make) - only add if compiling from source
        PACKAGES=(
            "git"                              # Version control - not in minimal
            "expect"                           # Automation tool - not in minimal
            "gnupg2"                          # GPG tools - may not be in minimal
            "gnupg"                           # GPG tools - may not be in minimal
            "fuse-overlayfs"                  # Container filesystem - not in minimal
            "python3-pip"                     # Python package manager - not in minimal
            "python3-pexpect"                 # Python automation - not in minimal
            "ansible"                         # Configuration management - not in minimal
            "policycoreutils-python-utils"   # SELinux Python tools - not in minimal
            "checkpolicy"                     # SELinux policy compiler - not in minimal
            "container-selinux"               # Container SELinux policies - not in minimal
            "dnf-plugins-core"                # DNF plugins - may not be in minimal
            "fuse3-libs"                      # FUSE libraries - not in minimal
            "podman"                          # Container runtime - not in minimal
        )
    fi

    # Download packages based on package manager
    if [ "$PACKAGE_MANAGER" = "apt" ]; then
        download_apt_packages
    else
        download_dnf_packages
    fi

    # Return to original directory
    cd "$SCRIPT_DIR"

    # Download Nix packages for offline installation (Ubuntu only - RHEL uses system podman)
    if [ "$PACKAGE_MANAGER" = "apt" ]; then
        echo -e "${YELLOW}Preparing Nix packages for offline installation...${NC}"

        # Check if Nix is available on the prepare system and install if needed
        if ! command -v nix-build >/dev/null 2>&1; then
            echo -e "${YELLOW}Nix not found, installing automatically for package preparation...${NC}"
            install_nix_for_preparation

            # Source Nix profile to make commands available
            if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
                source "$HOME/.nix-profile/etc/profile.d/nix.sh"
            fi

            # Also try sourcing from /etc/profile.d/nix.sh (multi-user install)
            if [ -f "/etc/profile.d/nix.sh" ]; then
                source "/etc/profile.d/nix.sh"
            fi

            # Start Nix daemon if it's not running (for multi-user installs)
            if [ -f "/etc/systemd/system/nix-daemon.service" ] && command -v systemctl >/dev/null 2>&1; then
                echo -e "${YELLOW}Starting Nix daemon...${NC}"
                sudo systemctl start nix-daemon || true
            fi

            # Check again after installation
            if ! command -v nix-build >/dev/null 2>&1; then
                echo -e "${RED}✗ Failed to install Nix${NC}"
                exit 1
            fi

            echo -e "${GREEN}✓ Nix installed successfully${NC}"
            TEMP_NIX_INSTALLED=true
        else
            echo -e "${GREEN}✓ Nix is already available${NC}"
            TEMP_NIX_INSTALLED=false
        fi
    else
        echo -e "${GREEN}✓ RHEL system detected - using system podman, skipping Nix installation${NC}"
        TEMP_NIX_INSTALLED=false
    fi

    # Set up Nix channels if not already configured (Ubuntu only)
    if [ "$PACKAGE_MANAGER" = "apt" ]; then
        echo -e "${YELLOW}Checking Nix channels configuration...${NC}"
        if ! nix-channel --list | grep -q "nixpkgs"; then
            echo -e "${YELLOW}Adding nixpkgs channel...${NC}"
            nix-channel --add https://nixos.org/channels/nixos-unstable nixpkgs
            nix-channel --update
            echo -e "${GREEN}✓ Nixpkgs channel added and updated${NC}"
        else
            echo -e "${GREEN}✓ Nixpkgs channel already configured${NC}"
            # Update channels to ensure we have latest packages
            echo -e "${YELLOW}Updating Nix channels...${NC}"
            nix-channel --update
        fi
    fi

    # Build and export podman with Nix (Ubuntu only - RHEL uses system podman)
    if [ "$PACKAGE_MANAGER" = "apt" ]; then
        echo -e "${YELLOW}Building podman package with Nix (this may take several minutes)...${NC}"

        # Build podman without installing it locally
        echo -e "${YELLOW}Running nix-build '<nixpkgs>' -A podman --no-out-link${NC}"

        # Capture both stdout and stderr separately
        BUILD_OUTPUT=$(mktemp)
        BUILD_ERROR=$(mktemp)

        if nix-build '<nixpkgs>' -A podman --no-out-link > "$BUILD_OUTPUT" 2> "$BUILD_ERROR"; then
            PODMAN_STORE_PATH=$(cat "$BUILD_OUTPUT")
            echo -e "${GREEN}✓ Successfully built podman${NC}"
        else
            echo -e "${RED}✗ Failed to build podman with nix-build${NC}"
            echo -e "${RED}Build output:${NC}"
            cat "$BUILD_OUTPUT"
            echo -e "${RED}Error output:${NC}"
            cat "$BUILD_ERROR"

            # Clean up temp files
            rm -f "$BUILD_OUTPUT" "$BUILD_ERROR"

            echo -e "${YELLOW}This could be due to:${NC}"
            echo -e "${YELLOW}  - Nix daemon not running properly${NC}"
            echo -e "${YELLOW}  - Permission issues with Nix store${NC}"
            echo -e "${YELLOW}  - Network issues downloading packages${NC}"
            echo -e "${YELLOW}Try running: sudo systemctl start nix-daemon${NC}"
            exit 1
        fi

        # Clean up temp files
        rm -f "$BUILD_OUTPUT" "$BUILD_ERROR"

        # Verify the store path exists
        if [ -z "$PODMAN_STORE_PATH" ] || [ ! -d "$PODMAN_STORE_PATH" ]; then
            echo -e "${RED}✗ Invalid podman store path: $PODMAN_STORE_PATH${NC}"
            exit 1
        fi

        echo -e "${GREEN}✓ Successfully built podman at: $PODMAN_STORE_PATH${NC}"

        # Get all runtime dependencies
        echo -e "${YELLOW}Calculating runtime dependencies...${NC}"
        PODMAN_PATHS=$(nix-store -qR "$PODMAN_STORE_PATH" 2>&1)
        DEPS_EXIT_CODE=$?

        if [ $DEPS_EXIT_CODE -ne 0 ] || [ -z "$PODMAN_PATHS" ]; then
            echo -e "${RED}✗ Failed to get podman dependencies${NC}"
            echo -e "${RED}Error: $PODMAN_PATHS${NC}"
            exit 1
        fi

        DEPS_COUNT=$(echo "$PODMAN_PATHS" | wc -l)
        echo -e "${GREEN}✓ Found $DEPS_COUNT dependencies${NC}"

        # Export podman and all its dependencies
        echo -e "${YELLOW}Exporting podman closure (this may take a few minutes)...${NC}"

        # Determine if we need sudo for nix-store export
        # Multi-user Nix installations require root access to export
        NIX_EXPORT_CMD="nix-store --export $PODMAN_PATHS"
        if [ -d "/nix/var/nix/db" ] && [ "$(stat -c %U /nix/var/nix/db 2>/dev/null)" = "root" ]; then
            # Multi-user installation - need sudo
            echo -e "${YELLOW}Detected multi-user Nix installation, using sudo for export...${NC}"
            NIX_EXPORT_CMD="sudo nix-store --export $PODMAN_PATHS"
        fi

        if $NIX_EXPORT_CMD > "$OUTPUT_DIR/packages/nix/podman-closure.nar" 2>/dev/null; then
            echo -e "${GREEN}✓ Successfully exported podman closure${NC}"

            # Fix ownership if we used sudo
            if [[ "$NIX_EXPORT_CMD" == sudo* ]]; then
                sudo chown $USER:$USER "$OUTPUT_DIR/packages/nix/podman-closure.nar"
            fi

            # Save the store path for reference
            echo "$PODMAN_STORE_PATH" > "$OUTPUT_DIR/packages/nix/podman-store-path.txt"
            echo -e "${GREEN}✓ Store path saved to podman-store-path.txt${NC}"

            # Get size of the export
            NAR_SIZE=$(du -h "$OUTPUT_DIR/packages/nix/podman-closure.nar" | cut -f1)
            echo -e "${GREEN}✓ Exported closure size: $NAR_SIZE${NC}"

            # Verify the file was created and has content
            if [ ! -s "$OUTPUT_DIR/packages/nix/podman-closure.nar" ]; then
                echo -e "${RED}✗ Exported file is empty or missing${NC}"
                exit 1
            fi
        else
            echo -e "${RED}✗ Failed to export podman closure${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}✓ RHEL system detected - skipping Nix podman build (will use system podman)${NC}"
    fi

    # Generate universal offline installation script that detects OS at runtime
    cat > "$OUTPUT_DIR/packages/install_packages_offline.sh" << 'EOF'
#!/bin/bash

# Script to install packages offline - detects OS at runtime

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
DEBS_DIR="$SCRIPT_DIR/debs"
RPMS_DIR="$SCRIPT_DIR/rpms"
NIX_DIR="$SCRIPT_DIR/nix"

echo -e "${YELLOW}Installing required packages for LME offline installation...${NC}"

# Detect OS at runtime
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="$ID"
elif [ -f /etc/redhat-release ]; then
    OS_ID="rhel"
elif [ -f /etc/debian_version ]; then
    OS_ID="debian"
else
    OS_ID="unknown"
fi

case "$OS_ID" in
    ubuntu|debian|linuxmint|pop)
        PACKAGE_MANAGER="apt"
        PACKAGES_DIR="$DEBS_DIR"
        PACKAGE_EXT="deb"
        ;;
    rhel|centos|rocky|almalinux|fedora)
        PACKAGE_MANAGER="dnf"
        PACKAGES_DIR="$RPMS_DIR"
        PACKAGE_EXT="rpm"
        ;;
    *)
        echo -e "${RED}✗ Unsupported operating system: $OS_ID${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}✓ Detected OS: $OS_ID (using $PACKAGE_MANAGER for $PACKAGE_EXT packages)${NC}"

if [ ! -d "$PACKAGES_DIR" ]; then
    echo -e "${RED}✗ Packages directory not found: $PACKAGES_DIR${NC}"
    exit 1
fi

# Install packages based on detected OS
echo -e "${YELLOW}Installing packages from local .$PACKAGE_EXT files...${NC}"
cd "$PACKAGES_DIR"

if [ "$PACKAGE_MANAGER" = "apt" ]; then
    # Install .deb packages
    if ls *.deb 1> /dev/null 2>&1; then
        echo -e "${YELLOW}Installing .deb packages...${NC}"
        sudo dpkg -i *.deb || true
        echo -e "${YELLOW}Fixing any broken dependencies...${NC}"
        sudo apt-get install -f -y
        echo -e "${GREEN}✓ Package installation complete!${NC}"
    else
        echo -e "${RED}✗ No .deb files found in debs directory${NC}"
        exit 1
    fi
else
    # Install .rpm packages
    if ls *.rpm 1> /dev/null 2>&1; then
        echo -e "${YELLOW}Installing .rpm packages...${NC}"
        
        # Count total packages
        TOTAL_RPMS=$(ls -1 *.rpm | wc -l)
        echo -e "${YELLOW}Found $TOTAL_RPMS RPM packages to install${NC}"
        
        # Try to install all at once with dnf (best dependency resolution)
        echo -e "${YELLOW}  Attempting batch installation with dnf localinstall...${NC}"
        if sudo dnf localinstall -y *.rpm 2>&1 | tee /tmp/dnf_install.log; then
            echo -e "${GREEN}✓ Package installation complete!${NC}"
        else
            echo -e "${YELLOW}⚠ dnf localinstall had issues, trying rpm directly...${NC}"
            
            # If dnf fails, try rpm with --nodeps for already-installed system packages
            # then use dnf to fix dependencies
            echo -e "${YELLOW}  Installing with rpm and fixing dependencies...${NC}"
            sudo rpm -Uvh --replacepkgs *.rpm 2>&1 | tee /tmp/rpm_install.log || true
            
            echo -e "${YELLOW}  Fixing dependencies with dnf...${NC}"
            sudo dnf install -y --allowerasing --skip-broken 2>&1 | tee -a /tmp/dnf_install.log || true
            
            echo -e "${GREEN}✓ Package installation attempted (check logs if issues occur)${NC}"
        fi
    else
        echo -e "${RED}✗ No .rpm files found in rpms directory${NC}"
        exit 1
    fi
fi

# Set up Nix and import podman (common for both Ubuntu and RHEL)
if [ -f "$NIX_DIR/podman-closure.nar" ]; then
    echo -e "${YELLOW}Setting up Nix and importing podman...${NC}"
    export PATH=$PATH:/nix/var/nix/profiles/default/bin
    sudo nix-store --import < "$NIX_DIR/podman-closure.nar"
    echo -e "${GREEN}✓ Podman packages imported from offline archive${NC}"
fi

echo -e "${GREEN}✓ All packages installed successfully!${NC}"
EOF

    chmod +x "$OUTPUT_DIR/packages/install_packages_offline.sh"

# Check Nix packages preparation results
if [ "$PACKAGE_MANAGER" = "apt" ]; then
    # Ubuntu systems should have Nix packages
    if [ -f "$OUTPUT_DIR/packages/nix/podman-closure.nar" ]; then
        echo -e "${GREEN}✓ Nix packages prepared successfully${NC}"
        echo -e "${GREEN}✓ Podman closure exported: $OUTPUT_DIR/packages/nix/podman-closure.nar${NC}"
    else
        echo -e "${RED}✗ No Nix packages found - podman-closure.nar is missing${NC}"
        echo -e "${RED}The prepare script failed to create the Nix packages${NC}"
        exit 1
    fi
else
    # RHEL systems don't need Nix packages
    echo -e "${GREEN}✓ RHEL system - Nix packages not required (using system podman)${NC}"
fi

# Verify podman installation for both regular user and root
echo -e "${YELLOW}Verifying podman installation...${NC}"
export PATH=/nix/var/nix/profiles/default/bin:$PATH

echo -e "${YELLOW}Checking podman for regular user...${NC}"
if command -v podman >/dev/null 2>&1; then
    PODMAN_VERSION=$(podman --version)
    echo -e "${GREEN}✓ Podman is available for regular user: $PODMAN_VERSION${NC}"
    echo -e "${GREEN}✓ Podman location: $(which podman)${NC}"
else
    echo -e "${RED}✗ Podman not found for regular user${NC}"
fi

echo -e "${YELLOW}Checking podman for root user...${NC}"
if sudo bash -c 'command -v podman' >/dev/null 2>&1; then
    ROOT_PODMAN_VERSION=$(sudo podman --version)
    echo -e "${GREEN}✓ Podman is available for root user: $ROOT_PODMAN_VERSION${NC}"
    echo -e "${GREEN}✓ Root podman location: $(sudo which podman)${NC}"
else
    echo -e "${RED}✗ Podman not found for root user${NC}"
    echo -e "${YELLOW}This will cause issues with 'sudo -i podman' commands${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All packages installed successfully!${NC}"
echo -e "${YELLOW}Next: Run ../load_containers.sh to load container images${NC}"

    chmod +x "$OUTPUT_DIR/packages/install_packages_offline.sh"

    # Generate systemd container fix script
    cat > "$OUTPUT_DIR/fix_container_configs.sh" << 'EOF'
#!/bin/bash

# Script to fix UserNS mapping issues in systemd container files

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Fixing UserNS mapping issues in systemd container files...${NC}"

SYSTEMD_CONTAINERS_DIR="/etc/containers/systemd"

if [ ! -d "$SYSTEMD_CONTAINERS_DIR" ]; then
    echo -e "${RED}✗ Systemd containers directory not found: $SYSTEMD_CONTAINERS_DIR${NC}"
    exit 1
fi

# List of containers that commonly have UserNS mapping issues in offline mode
CONTAINERS_TO_FIX=(
    "lme-fleet-distribution.container"
    "lme-fleet-server.container"
    "lme-elasticsearch.container"
    "lme-kibana.container"
    "lme-wazuh-manager.container"
    "lme-elastalert.container"
)

for container_file in "${CONTAINERS_TO_FIX[@]}"; do
    CONTAINER_PATH="$SYSTEMD_CONTAINERS_DIR/$container_file"
    
    if [ -f "$CONTAINER_PATH" ]; then
        echo -e "${YELLOW}Fixing $container_file...${NC}"
        
        # Backup original file
        sudo cp "$CONTAINER_PATH" "$CONTAINER_PATH.backup.$(date +%Y%m%d-%H%M%S)"
        
        # Remove problematic UserNS line
        sudo sed -i '/^UserNS=auto:uidmapping=/d' "$CONTAINER_PATH"
        
        echo -e "${GREEN}✓ Fixed $container_file${NC}"
    else
        echo -e "${YELLOW}⚠ $container_file not found, skipping${NC}"
    fi
done

echo -e "${GREEN}✓ Container configuration fixes applied${NC}"
echo -e "${YELLOW}Reloading systemd daemon...${NC}"
sudo systemctl daemon-reload

echo -e "${GREEN}✓ SystemD container fixes complete${NC}"
EOF

    chmod +x "$OUTPUT_DIR/fix_container_configs.sh"

    echo -e "${GREEN}✓ Packages downloaded and scripts created${NC}"
}

# Download agent installers for offline installation
download_agents() {
    echo -e "${YELLOW}Downloading agent installers for offline installation...${NC}"

    # Create agents directory
    mkdir -p "$OUTPUT_DIR/agents"
    cd "$OUTPUT_DIR/agents"

    echo -e "${YELLOW}Using Elastic Stack version: $STACK_VERSION${NC}"
    echo -e "${YELLOW}Using Wazuh version: $WAZUH_VERSION${NC}"

    # Download Wazuh agents
    echo -e "${YELLOW}Downloading Wazuh $WAZUH_VERSION agents...${NC}"

    # Wazuh Windows agent
    echo -e "${YELLOW}  Downloading Wazuh Windows agent...${NC}"
    if download_file "https://packages.wazuh.com/4.x/windows/wazuh-agent-${WAZUH_VERSION}-1.msi" "wazuh-agent-${WAZUH_VERSION}-1.msi"; then
        echo -e "${GREEN}  ✓ Wazuh Windows agent downloaded${NC}"
    else
        echo -e "${RED}  ✗ Failed to download Wazuh Windows agent${NC}"
    fi

    # Wazuh Linux DEB agent
    echo -e "${YELLOW}  Downloading Wazuh Linux DEB agent...${NC}"
    if download_file "https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_${WAZUH_VERSION}-1_amd64.deb" "wazuh-agent_${WAZUH_VERSION}-1_amd64.deb"; then
        echo -e "${GREEN}  ✓ Wazuh Linux DEB agent downloaded${NC}"
    else
        echo -e "${RED}  ✗ Failed to download Wazuh Linux DEB agent${NC}"
    fi

    # Wazuh Linux RPM agent
    echo -e "${YELLOW}  Downloading Wazuh Linux RPM agent...${NC}"
    if download_file "https://packages.wazuh.com/4.x/yum/wazuh-agent-${WAZUH_VERSION}-1.x86_64.rpm" "wazuh-agent-${WAZUH_VERSION}-1.x86_64.rpm"; then
        echo -e "${GREEN}  ✓ Wazuh Linux RPM agent downloaded${NC}"
    else
        echo -e "${RED}  ✗ Failed to download Wazuh Linux RPM agent${NC}"
    fi

    # Download Elastic agents
    echo -e "${YELLOW}Downloading Elastic Agent $STACK_VERSION...${NC}"

    # Elastic Agent Windows
    echo -e "${YELLOW}  Downloading Elastic Agent Windows...${NC}"
    if download_file "https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-${STACK_VERSION}-windows-x86_64.zip" "elastic-agent-${STACK_VERSION}-windows-x86_64.zip"; then
        echo -e "${GREEN}  ✓ Elastic Agent Windows downloaded${NC}"
    else
        echo -e "${RED}  ✗ Failed to download Elastic Agent Windows${NC}"
    fi

    # Elastic Agent Linux DEB
    echo -e "${YELLOW}  Downloading Elastic Agent Linux DEB...${NC}"
    if download_file "https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-${STACK_VERSION}-amd64.deb" "elastic-agent-${STACK_VERSION}-amd64.deb"; then
        echo -e "${GREEN}  ✓ Elastic Agent Linux DEB downloaded${NC}"
    else
        echo -e "${RED}  ✗ Failed to download Elastic Agent Linux DEB${NC}"
    fi

    # Elastic Agent Linux RPM
    echo -e "${YELLOW}  Downloading Elastic Agent Linux RPM...${NC}"
    if download_file "https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-${STACK_VERSION}-x86_64.rpm" "elastic-agent-${STACK_VERSION}-x86_64.rpm"; then
        echo -e "${GREEN}  ✓ Elastic Agent Linux RPM downloaded${NC}"
    else
        echo -e "${RED}  ✗ Failed to download Elastic Agent Linux RPM${NC}"
    fi

    # Elastic Agent Linux TAR.GZ
    echo -e "${YELLOW}  Downloading Elastic Agent Linux TAR.GZ...${NC}"
    if download_file "https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-${STACK_VERSION}-linux-x86_64.tar.gz" "elastic-agent-${STACK_VERSION}-linux-x86_64.tar.gz"; then
        echo -e "${GREEN}  ✓ Elastic Agent Linux TAR.GZ downloaded${NC}"
    else
        echo -e "${RED}  ✗ Failed to download Elastic Agent Linux TAR.GZ${NC}"
    fi

    cd "$LME_ROOT"
    echo -e "${GREEN}✓ Agent installers downloaded${NC}"
}

# Download CVE database for offline Wazuh vulnerability detection
download_cve_database() {
    echo -e "${YELLOW}Downloading CVE database for offline Wazuh vulnerability detection...${NC}"

    # Create cve directory
    mkdir -p "$OUTPUT_DIR/cve"
    cd "$OUTPUT_DIR/cve"

    # Get the latest CVE database snapshot link
    echo -e "${YELLOW}  Getting latest CVE database snapshot link...${NC}"
    if CVE_INFO=$(curl -s -X GET "https://cti.wazuh.com/api/v1/catalog/contexts/vd_1.0.0/consumers/vd_4.8.0" | jq -r '.data | "\(.last_snapshot_link)\n\(.last_snapshot_at)"'); then
        CVE_LINK=$(echo "$CVE_INFO" | head -1)
        CVE_DATE=$(echo "$CVE_INFO" | tail -1)

        echo -e "${GREEN}  ✓ Found CVE database snapshot from: $CVE_DATE${NC}"
        echo -e "${YELLOW}  Downloading CVE database...${NC}"

        # Download the CVE database
        if curl -L "$CVE_LINK" -o cves.zip; then
            echo -e "${GREEN}  ✓ CVE database downloaded successfully${NC}"

            # Verify the download
            if [ -f "cves.zip" ] && [ -s "cves.zip" ]; then
                FILE_SIZE=$(du -h cves.zip | cut -f1)
                echo -e "${GREEN}  ✓ CVE database size: $FILE_SIZE${NC}"
            else
                echo -e "${RED}  ✗ Downloaded CVE database appears to be empty${NC}"
            fi
        else
            echo -e "${RED}  ✗ Failed to download CVE database${NC}"
        fi
    else
        echo -e "${RED}  ✗ Failed to get CVE database snapshot information${NC}"
    fi

    cd "$LME_ROOT"
    echo -e "${GREEN}✓ CVE database download completed${NC}"
}

# Create single archive with all offline resources
create_offline_archive() {
    echo -e "${YELLOW}Creating offline installation archive...${NC}"

    ARCHIVE_NAME="lme-offline-$(date +%Y%m%d-%H%M%S).tar.gz"
    # Create archive in parent directory to avoid including it in itself
    ARCHIVE_PATH="$(dirname "$LME_ROOT")/$ARCHIVE_NAME"

    echo -e "${YELLOW}Creating compressed archive: $ARCHIVE_PATH${NC}"
    cd "$(dirname "$LME_ROOT")"

    # Include the entire LME directory (which now contains offline_resources)
    LME_DIR_NAME="$(basename "$LME_ROOT")"

    if tar -czf "$ARCHIVE_PATH" "$LME_DIR_NAME"; then
        echo -e "${GREEN}✓ Archive created successfully: $ARCHIVE_PATH${NC}"

        # Get archive size
        ARCHIVE_SIZE=$(du -h "$ARCHIVE_PATH" | cut -f1)
        echo -e "${GREEN}Archive size: $ARCHIVE_SIZE${NC}"
    else
        echo -e "${RED}✗ Failed to create archive${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ Offline archive created: $ARCHIVE_NAME${NC}"
    echo -e "${YELLOW}Archive location: $ARCHIVE_PATH${NC}"
    echo -e "${YELLOW}Transfer this file to your target system and extract it for offline installation.${NC}"
}

# Generate load script for target system
generate_load_script() {
    echo -e "${YELLOW}Generating container load script...${NC}"

    cat > "$OUTPUT_DIR/load_containers.sh" << 'EOF'
#!/bin/bash

# Simple Container Loading Script for Offline LME Installation

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
IMAGES_DIR="$SCRIPT_DIR/container_images"

echo -e "${YELLOW}Loading container images for offline LME installation...${NC}"

# Ensure proper PATH for Nix binaries
export PATH="/nix/var/nix/profiles/default/bin:$PATH"

# Simple mapping of tar files to target names
declare -A IMAGE_MAP
IMAGE_MAP["elasticsearch_8.18.8.tar"]="localhost/elasticsearch:LME_LATEST"
IMAGE_MAP["kibana_8.18.8.tar"]="localhost/kibana:LME_LATEST"
IMAGE_MAP["elastic-agent_8.18.8.tar"]="localhost/elastic-agent:LME_LATEST"
IMAGE_MAP["wazuh-manager_4.9.1.tar"]="localhost/wazuh-manager:LME_LATEST"
IMAGE_MAP["elastalert2_2.20.0.tar"]="localhost/elastalert2:LME_LATEST"
IMAGE_MAP["distribution_lite-8.18.8.tar"]="localhost/distribution:LME_LATEST"

LOADED_COUNT=0
FAILED_COUNT=0

for tar_file in "$IMAGES_DIR"/*.tar; do
    if [ -f "$tar_file" ]; then
        filename=$(basename "$tar_file")
        target_name="${IMAGE_MAP[$filename]}"

        if [ -z "$target_name" ]; then
            echo -e "${RED}✗ Unknown tar file: $filename${NC}"
            FAILED_COUNT=$((FAILED_COUNT + 1))
            continue
        fi

        # Check if already tagged
        if sudo bash -c "export PATH=/nix/var/nix/profiles/default/bin:\$PATH; podman images --format '{{.Repository}}:{{.Tag}}'" | grep -q "$target_name"; then
            echo -e "${GREEN}✓ $filename already loaded and tagged${NC}"
            continue
        fi

        echo -e "${YELLOW}Loading $filename...${NC}"
        if sudo bash -c "export PATH=/nix/var/nix/profiles/default/bin:\$PATH; podman load -i '$tar_file'"; then
            echo -e "${GREEN}✓ Loaded $filename${NC}"

            # Get the image that was just loaded and tag it
            echo -e "${YELLOW}  Tagging as $target_name...${NC}"

            # Find the loaded image and tag it
            case "$filename" in
                "elasticsearch_8.18.8.tar")
                    sudo bash -c "export PATH=/nix/var/nix/profiles/default/bin:\$PATH; podman tag docker.elastic.co/elasticsearch/elasticsearch:8.18.8 $target_name"
                    ;;
                "kibana_8.18.8.tar")
                    sudo bash -c "export PATH=/nix/var/nix/profiles/default/bin:\$PATH; podman tag docker.elastic.co/kibana/kibana:8.18.8 $target_name"
                    ;;
                "elastic-agent_8.18.8.tar")
                    sudo bash -c "export PATH=/nix/var/nix/profiles/default/bin:\$PATH; podman tag docker.elastic.co/beats/elastic-agent:8.18.8 $target_name"
                    ;;
                "wazuh-manager_4.9.1.tar")
                    sudo bash -c "export PATH=/nix/var/nix/profiles/default/bin:\$PATH; podman tag docker.io/wazuh/wazuh-manager:4.9.1 $target_name"
                    ;;
                "elastalert2_2.20.0.tar")
                    sudo bash -c "export PATH=/nix/var/nix/profiles/default/bin:\$PATH; podman tag docker.io/jertel/elastalert2:2.20.0 $target_name"
                    ;;
                "distribution_lite-8.18.8.tar")
                    sudo bash -c "export PATH=/nix/var/nix/profiles/default/bin:\$PATH; podman tag docker.elastic.co/package-registry/distribution:lite-8.18.8 $target_name"
                    ;;
            esac

            echo -e "${GREEN}  ✓ Tagged as $target_name${NC}"
            LOADED_COUNT=$((LOADED_COUNT + 1))
        else
            echo -e "${RED}✗ Failed to load $filename${NC}"
            FAILED_COUNT=$((FAILED_COUNT + 1))
        fi
    fi
done

echo
echo -e "${GREEN}Container loading summary:${NC}"
echo -e "${GREEN}  Successfully loaded: $LOADED_COUNT${NC}"
if [ $FAILED_COUNT -gt 0 ]; then
    echo -e "${RED}  Failed to load: $FAILED_COUNT${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All container images loaded and tagged successfully${NC}"
EOF

    chmod +x "$OUTPUT_DIR/load_containers.sh"
    echo -e "${GREEN}✓ Container load script created: $OUTPUT_DIR/load_containers.sh${NC}"
}



# Main execution
main() {
    echo -e "${GREEN}LME Offline Preparation Script${NC}"
    echo -e "${GREEN}==============================${NC}"
    echo

    # Initialize cleanup tracking
    TEMP_PODMAN_INSTALLED=false
    TEMP_NIX_INSTALLED=false

    check_internet
    check_podman
    create_output_dir
    download_containers
    download_packages
    download_agents
    download_cve_database
    generate_load_script
    create_offline_archive

    echo -e "${GREEN}✓ Offline preparation complete!${NC}"
    echo -e "${YELLOW}Resources saved to archive: lme-offline-*.tar.gz${NC}"
    echo
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Transfer the lme-offline-*.tar.gz file to your target system"
    echo "2. Extract: tar -xzf lme-offline-*.tar.gz"
    echo "3. Navigate to extracted directory: cd LME"
    echo "4. Run installation: ./install.sh --offline"
    echo ""
    echo "The install script will automatically handle packages, containers, and configuration."

    # Cleanup temporary podman installation
    cleanup_temp_podman
}

# Run main function
main
