#!/bin/bash

# Colors for better readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default playbook location - can be overridden with command line argument
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PLAYBOOK_PATH="$SCRIPT_DIR/ansible/site.yml"
CUSTOM_IP=""
HAS_SUDO_ACCESS=""
IPVAR=""
DEBUG_MODE="false"
OFFLINE_MODE="false"
SKIP_PACKAGES="false"

# Environment variables for non-interactive mode
NON_INTERACTIVE=${NON_INTERACTIVE:-false}
AUTO_CREATE_ENV=${AUTO_CREATE_ENV:-false}
AUTO_IP=${AUTO_IP:-""}

# Print usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "OPTIONS:"
    echo "  -i, --ip IP_ADDRESS           Specify IP address manually"
    echo "  -d, --debug                   Enable debug mode for verbose output"
    echo "  -o, --offline                 Enable offline mode (skip internet-dependent tasks)"
    echo "  --skip-packages               Skip package installation (for development)"
    echo "  -p, --playbook PLAYBOOK_PATH  Specify path to playbook (default: ./ansible/site.yml)"
    echo "  -h, --help                    Show this help message"
    echo
    echo "Environment Variables:"
    echo "  NON_INTERACTIVE=true          Run in non-interactive mode (default: false)"
    echo "  AUTO_CREATE_ENV=true          Automatically create environment file (default: false)"
    echo "  AUTO_IP=IP_ADDRESS           Automatically use specified IP address"
    echo
    exit 1
}

cd "$SCRIPT_DIR"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--ip)
            CUSTOM_IP="$2"
            shift 2
            ;;
        -d|--debug)
            DEBUG_MODE="true"
            shift
            ;;
        -o|--offline)
            OFFLINE_MODE="true"
            shift
            ;;
        --skip-packages)
            SKIP_PACKAGES="true"
            shift
            ;;
        -p|--playbook)
            PLAYBOOK_PATH="$2"
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

# Function to check if ansible is installed
check_ansible() {
    # Add /usr/local/bin to PATH for pip-installed packages
    export PATH="/usr/local/bin:$PATH"
    
    if command -v ansible &> /dev/null; then
        echo -e "${GREEN}✓ Ansible is already installed!${NC}"
        ansible --version | head -n 1
        return 0
    else
        echo -e "${YELLOW}⚠ Ansible is not installed.${NC}"
        return 1
    fi
}

# Function to detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    elif type lsb_release >/dev/null 2>&1; then
        DISTRO=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        DISTRO=$DISTRIB_ID
    elif [ -f /etc/debian_version ]; then
        DISTRO="debian"
    else
        DISTRO=$(uname -s)
    fi
    
    echo -e "${GREEN}Detected distribution: ${DISTRO}${NC}"
}

# Function to wait for apt locks to be released
wait_for_apt() {
    local max_attempts=60  # Maximum number of attempts (10 minutes total)
    local attempt=1
    local max_kill_attempts=3  # Maximum number of kill attempts
    local kill_attempt=0
    
    echo -e "${YELLOW}Waiting for apt locks to be released...${NC}"
    
    while [ $attempt -le $max_attempts ]; do
        # First check if any apt/dpkg processes are running
        if ! lsof /var/lib/apt/lists/lock >/dev/null 2>&1 && \
           ! lsof /var/lib/dpkg/lock-frontend >/dev/null 2>&1 && \
           ! lsof /var/lib/dpkg/lock >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Apt locks are free${NC}"
            return 0
        fi
        
        # If we've been waiting for a long time (30+ attempts), try to kill hung processes
        if [ $attempt -gt 30 ] && [ $kill_attempt -lt $max_kill_attempts ]; then
            kill_attempt=$((kill_attempt + 1))
            echo -e "${YELLOW}Attempting to kill hung apt processes (attempt $kill_attempt of $max_kill_attempts)...${NC}"
            # Find processes holding locks and kill them
            for lock_file in /var/lib/apt/lists/lock /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock; do
                pid=$(lsof $lock_file 2>/dev/null | awk 'NR>1 {print $2}' | uniq)
                if [ -n "$pid" ]; then
                    echo -e "${YELLOW}Killing process $pid holding lock on $lock_file${NC}"
                    sudo kill -9 $pid >/dev/null 2>&1 || true
                fi
            done
            sleep 5  # Give it a moment to clean up after kill
        fi
        
        echo -n "."
        sleep 10
        attempt=$((attempt + 1))
    done
    
    echo -e "\n${RED}Error: Apt is still locked after 10 minutes. Please check system processes.${NC}"
    return 1
}

# Function to run apt-get with retries
apt_get_wrapper() {
    local max_retries=5
    local retry=0
    local command=("$@")
    local result=1
    
    while [ $retry -lt $max_retries ] && [ $result -ne 0 ]; do
        if [ $retry -gt 0 ]; then
            echo -e "${YELLOW}Retrying apt-get command (attempt $((retry+1)) of $max_retries)...${NC}"
            # Wait for any locks before retrying
            wait_for_apt || return 1
        fi
        
        echo -e "${YELLOW}Running: ${command[*]}${NC}"
        "${command[@]}"
        result=$?
        
        if [ $result -ne 0 ]; then
            retry=$((retry+1))
            echo -e "${YELLOW}Command failed with exit code $result. Waiting before retry...${NC}"
            sleep 10
        fi
    done
    
    if [ $result -ne 0 ]; then
        echo -e "${RED}Command failed after $max_retries retries: ${command[*]}${NC}"
    fi
    
    return $result
}

# Function to install Ansible on different distributions
install_ansible() {
    if [ "$OFFLINE_MODE" = "true" ]; then
        echo -e "${RED}✗ Cannot install Ansible in offline mode.${NC}"
        echo -e "${YELLOW}Please install Ansible manually before running this script in offline mode.${NC}"
        echo -e "${YELLOW}For Ubuntu/Debian: sudo apt-get install ansible${NC}"
        echo -e "${YELLOW}For RHEL/CentOS: sudo dnf install ansible${NC}"
        echo -e "${YELLOW}For other distributions, consult your package manager.${NC}"
        exit 1
    fi

    echo -e "${YELLOW}Installing Ansible...${NC}"

    # Set noninteractive mode for apt-based installations
    export DEBIAN_FRONTEND=noninteractive

    case $DISTRO in
        ubuntu|debian|linuxmint|pop)
            sudo ln -fs /usr/share/zoneinfo/Etc/UTC /etc/localtime
            wait_for_apt || exit 1
            apt_get_wrapper sudo apt-get update
            wait_for_apt || exit 1
            apt_get_wrapper sudo apt-get install -y ansible
            ;;
        fedora)
            sudo dnf install -y ansible
            ;;
        centos|rhel|rocky|almalinux)
            # Ask user which installation method to use
            use_pip=false
            if [ "$NON_INTERACTIVE" != "true" ]; then
                echo -e "${YELLOW}Choose Ansible installation method:${NC}"
                echo "  1. Fedora EPEL repository (default)"
                echo "  2. Python pip"
                read -p "Select option (1 or 2): " install_choice

                if [[ "$install_choice" == "2" ]]; then
                    use_pip=true
                fi
            fi

            if [ "$use_pip" = true ]; then
                # Install via pip
                echo -e "${YELLOW}Installing Ansible via pip...${NC}"
                sudo dnf install -y python3-pip
                sudo pip3 install ansible
                # Create symlink to make pip-installed ansible available in PATH
                if [ -f /usr/local/bin/ansible ] && [ ! -f /usr/bin/ansible ]; then
                    sudo ln -sf /usr/local/bin/ansible /usr/bin/ansible
                    sudo ln -sf /usr/local/bin/ansible-vault /usr/bin/ansible-vault
                    echo -e "${GREEN}✓ Created symlink for ansible in /usr/bin${NC}"
                fi
                echo -e "${GREEN}✓ Ansible installed via pip${NC}"
            else
                # Install EPEL repository first
                echo "Installing EPEL repository..."
                if ! sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-$(rpm -E %rhel).noarch.rpm; then
                    echo -e "${RED}✗ Failed to install EPEL repository${NC}"
                    exit 1
                fi
                echo -e "${GREEN}✓ EPEL repository installed${NC}"

                # For RHEL, you might also need to enable CodeReady Builder repository
                if [[ "$DISTRO" == "rhel" ]]; then
                    sudo subscription-manager repos --enable codeready-builder-for-rhel-$(rpm -E %rhel)-$(arch)-rpms 2>/dev/null || true
                fi

                # Now try to install ansible via dnf
                if sudo dnf install -y ansible; then
                    echo -e "${GREEN}✓ Ansible installed via dnf${NC}"
                else
                    echo -e "${YELLOW}⚠ dnf installation failed, trying pip installation...${NC}"
                    sudo dnf install -y python3-pip
                    sudo pip3 install ansible
                    # Create symlink to make pip-installed ansible available in PATH
                    if [ -f /usr/local/bin/ansible ] && [ ! -f /usr/bin/ansible ]; then
                        sudo ln -sf /usr/local/bin/ansible /usr/bin/ansible
                        sudo ln -sf /usr/local/bin/ansible-vault /usr/bin/ansible-vault
                        echo -e "${GREEN}✓ Created symlink for ansible in /usr/bin${NC}"
                    fi
                fi
            fi
            ;;
        arch|manjaro)
            sudo pacman -Sy --noconfirm ansible
            ;;
        opensuse*|suse)
            sudo zypper install -y ansible
            ;;
        alpine)
            sudo apk add ansible
            ;;
        *)
            echo -e "${RED}Unsupported distribution: $DISTRO${NC}"
            echo "Please install Ansible manually and run the script again."
            exit 1
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Ansible installation completed successfully!${NC}"
    else
        echo -e "${RED}✗ Ansible installation failed.${NC}"
        exit 1
    fi
}

# Function to check if playbook exists
check_playbook() {
    if [ ! -f "$PLAYBOOK_PATH" ]; then
        echo -e "${RED}Error: Playbook not found at $PLAYBOOK_PATH${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Playbook found at $PLAYBOOK_PATH${NC}"
}

# Function to find IP addresses of the machine
get_ip_addresses() {
    echo -e "${YELLOW}Detecting IP addresses...${NC}"
    
    # If AUTO_IP is set, use it
    if [ -n "$AUTO_IP" ]; then
        echo -e "${GREEN}Using provided AUTO_IP: ${AUTO_IP}${NC}"
        IPVAR="$AUTO_IP"
        return 0
    fi
    
    # Array to store the found IP addresses
    declare -a IPS
    
    # Try different methods to find IP addresses
    
    # Method 1: Using hostname
    if command -v hostname >/dev/null 2>&1; then
        if hostname -I >/dev/null 2>&1; then
            HOSTNAME_IPS=$(hostname -I)
            for ip in $HOSTNAME_IPS; do
                if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    IPS+=("$ip")
                fi
            done
        fi
    fi
    
    # Method 2: Using ip command
    if command -v ip >/dev/null 2>&1; then
        IP_ADDR_IPS=$(ip -4 addr show scope global | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
        for ip in $IP_ADDR_IPS; do
            if [[ ! " ${IPS[@]} " =~ " ${ip} " ]]; then
                IPS+=("$ip")
            fi
        done
    fi
    
    # Method 3: Using ifconfig command
    if command -v ifconfig >/dev/null 2>&1; then
        IFCONFIG_IPS=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')
        for ip in $IFCONFIG_IPS; do
            if [[ ! " ${IPS[@]} " =~ " ${ip} " ]]; then
                IPS+=("$ip")
            fi
        done
    fi
    
    # If a custom IP was provided via command line, use it instead
    if [[ -n "$CUSTOM_IP" ]]; then
        echo -e "${GREEN}Using provided IP address: ${CUSTOM_IP}${NC}"
        IPVAR="$CUSTOM_IP"
        return 0
    fi
    
    # Check if we found any IP addresses
    if [ ${#IPS[@]} -eq 0 ]; then
        echo -e "${RED}Could not detect any IP addresses.${NC}"
        if [ "$NON_INTERACTIVE" = "true" ]; then
            echo -e "${RED}No IP address detected and running in non-interactive mode.${NC}"
            exit 1
        fi
        prompt_for_ip
        return 0
    fi
    
    # Print all detected IP addresses
    echo -e "${GREEN}Found ${#IPS[@]} IP address(es):${NC}"
    for i in "${!IPS[@]}"; do
        echo "  $((i+1)). ${IPS[$i]}"
    done
    
    # In non-interactive mode, use the first IP
    if [ "$NON_INTERACTIVE" = "true" ]; then
        IPVAR="${IPS[0]}"
        echo -e "${GREEN}Using first detected IP in non-interactive mode: ${IPVAR}${NC}"
        return 0
    fi
    
    # Ask user to select an IP or use the first one detected
    prompt_ip_selection
    
    return 0
}

# Function to prompt user to select an IP address from the detected ones
prompt_ip_selection() {
    echo
    echo -e "${YELLOW}Please select an IP address to use (or enter a custom one):${NC}"
    echo "  Enter a number from the list above"
    echo "  Enter 'c' to specify a custom IP"
    echo "  Press Enter to use the first detected IP (${IPS[0]})"
    
    read -p "> " selection
    
    if [[ -z "$selection" ]]; then
        # Default to first IP
        IPVAR="${IPS[0]}"
        echo -e "${GREEN}Using default IP: ${IPVAR}${NC}"
    elif [[ "$selection" == "c" ]]; then
        # Custom IP
        prompt_for_ip
    elif [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#IPS[@]}" ]; then
        # Selected from list
        IPVAR="${IPS[$((selection-1))]}"
        echo -e "${GREEN}Using selected IP: ${IPVAR}${NC}"
    else
        echo -e "${RED}Invalid selection. Using the first detected IP.${NC}"
        IPVAR="${IPS[0]}"
    fi
}

# Function to prompt user to enter a custom IP address
prompt_for_ip() {
    local valid_ip=false
    
    while [ "$valid_ip" = false ]; do
        echo -e "${YELLOW}Please enter a valid IP address:${NC}"
        read -p "> " custom_ip
        
        if [[ $custom_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            IPVAR="$custom_ip"
            valid_ip=true
            echo -e "${GREEN}Using custom IP: ${IPVAR}${NC}"
        else
            echo -e "${RED}Invalid IP format. Please use format: xxx.xxx.xxx.xxx${NC}"
        fi
    done
}

# Function to check for sudo access
check_sudo_access() {
    echo -e "${YELLOW}Checking sudo access...${NC}"
    
    # First check for passwordless sudo
    if sudo -n true 2>/dev/null; then
        echo -e "${GREEN}✓ Passwordless sudo access available${NC}"
        HAS_SUDO_ACCESS="true"
        return 0
    fi
    
    # If no passwordless sudo, check if we can use sudo with a password
    echo -e "${YELLOW}⚠ Passwordless sudo access not available, checking if sudo access is possible with password...${NC}"
    
    # Attempt to use sudo with password prompt
    if sudo -v; then
        echo -e "${GREEN}✓ Sudo access available (will require password)${NC}"
        HAS_SUDO_ACCESS="false"  # This will trigger -K in ansible-playbook
        return 0
    else
        echo -e "${RED}✗ No sudo access available. This script requires sudo privileges.${NC}"
        exit 1
    fi
}

# Function to run the playbook
run_playbook() {
    echo -e "${YELLOW}Running Ansible playbook...${NC}"
    
    # If sudo requires password, we need to pass -K for sudo password
    if [ "${HAS_SUDO_ACCESS}" = "false" ]; then
        ANSIBLE_OPTS="-K"
        echo -e "${YELLOW}Sudo password will be required for privileged operations${NC}"
        # Verify sudo access is still valid
        if ! sudo -v; then
            echo -e "${RED}✗ Sudo access verification failed. Please ensure you have sudo privileges.${NC}"
            exit 1
        fi
    else
        ANSIBLE_OPTS=""
    fi
    
    # Add debug mode if enabled
    if [ "$DEBUG_MODE" = "true" ]; then
        echo -e "${YELLOW}Debug mode enabled - verbose output will be shown${NC}"
        ANSIBLE_OPTS="$ANSIBLE_OPTS -e debug_mode=true -vvvv"
    fi

    # Add offline mode message
    if [ "$OFFLINE_MODE" = "true" ]; then
        echo -e "${YELLOW}⚠ Running in offline mode - skipping internet-dependent tasks${NC}"
    fi

    # Run the main installation playbook
    echo -e "${YELLOW}Running main installation playbook...${NC}"

    # Set Ansible temp directories to avoid I/O errors
    export ANSIBLE_LOCAL_TEMP=/opt/ansible-tmp
    export ANSIBLE_REMOTE_TEMP=/opt/ansible-tmp
    sudo mkdir -p /opt/ansible-tmp
    sudo chown $(whoami):$(whoami) /opt/ansible-tmp

    if [ -f "$SCRIPT_DIR/inventory" ]; then
        ansible-playbook -i "$SCRIPT_DIR/inventory" "$PLAYBOOK_PATH" --extra-vars '{"has_sudo_access":"'"${HAS_SUDO_ACCESS}"'","clone_dir":"'"${SCRIPT_DIR}"'","offline_mode":'"${OFFLINE_MODE}"'}' $ANSIBLE_OPTS
    else
        ansible-playbook "$PLAYBOOK_PATH" --extra-vars '{"has_sudo_access":"'"${HAS_SUDO_ACCESS}"'","clone_dir":"'"${SCRIPT_DIR}"'","offline_mode":'"${OFFLINE_MODE}"'}' $ANSIBLE_OPTS
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Main installation playbook completed successfully!${NC}"
    else
        echo -e "${RED}✗ Main installation playbook failed.${NC}"
        exit 1
    fi
}

# Main script execution
echo "==============================================="
echo "    Ansible Setup and Playbook Runner"
echo "==============================================="

# Display offline mode status early
if [ "$OFFLINE_MODE" = "true" ]; then
    echo -e "${YELLOW}⚠ OFFLINE MODE ENABLED${NC}"
    echo -e "${YELLOW}⚠ Internet-dependent operations will be skipped${NC}"
    echo

    # Validate offline resources exist
    if [ ! -d "$SCRIPT_DIR/offline_resources" ]; then
        echo -e "${RED}✗ Offline resources directory not found: $SCRIPT_DIR/offline_resources${NC}"
        echo -e "${YELLOW}This means prepare_offline.sh was not run successfully or the offline archive was not extracted properly.${NC}"
        echo -e "${YELLOW}Please ensure you:${NC}"
        echo -e "${YELLOW}  1. Ran prepare_offline.sh on an internet-connected machine${NC}"
        echo -e "${YELLOW}  2. Transferred the resulting lme-offline-*.tar.gz to this offline machine${NC}"
        echo -e "${YELLOW}  3. Extracted the tar.gz: tar -xzf lme-offline-*.tar.gz${NC}"
        echo -e "${YELLOW}  4. Changed into the LME directory: cd LME${NC}"
        echo -e "${YELLOW}  5. Then run: ./install.sh --offline${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ Offline resources directory found${NC}"

    # Validate offline archive if validation script exists
    if [ -f "$SCRIPT_DIR/scripts/validate_offline_archive.sh" ]; then
        echo -e "${YELLOW}Validating offline resources...${NC}"
        if "$SCRIPT_DIR/scripts/validate_offline_archive.sh" -d "$SCRIPT_DIR/offline_resources" 2>/dev/null; then
            echo -e "${GREEN}✓ Offline resources validation passed${NC}"
        else
            echo -e "${YELLOW}⚠ Offline resources validation failed or incomplete${NC}"
            echo -e "${YELLOW}Continuing with installation...${NC}"
        fi
        echo
    fi

    # Install packages
        if [ "$SKIP_PACKAGES" = "true" ]; then
            echo -e "${YELLOW}Skipping package installation (--skip-packages flag enabled)${NC}"
        else
            echo -e "${YELLOW}Installing required packages...${NC}"
            cd "$SCRIPT_DIR/offline_resources/packages"

            # Detect OS and install appropriate packages
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
                    PACKAGES_DIR="debs"
                    PACKAGE_EXT="deb"
                    ;;
                rhel|centos|rocky|almalinux|fedora)
                    PACKAGES_DIR="rpms"
                    PACKAGE_EXT="rpm"
                    ;;
                *)
                    echo -e "${RED}✗ Unsupported operating system: $OS_ID${NC}"
                    exit 1
                    ;;
            esac

            echo -e "${GREEN}✓ Detected OS: $OS_ID (looking for $PACKAGE_EXT packages)${NC}"

            if [ ! -d "$PACKAGES_DIR" ]; then
                echo -e "${RED}✗ Packages directory not found: $PACKAGES_DIR${NC}"
                exit 1
            fi

            cd "$PACKAGES_DIR"
            if ls *.$PACKAGE_EXT 1> /dev/null 2>&1; then
                echo -e "${YELLOW}Installing .$PACKAGE_EXT packages...${NC}"

                # For RPM packages, install all at once for proper dependency resolution
                if [ "$PACKAGE_EXT" = "rpm" ]; then
                    echo -e "${YELLOW}  Installing all RPM packages together...${NC}"
                    
                    # Count packages
                    TOTAL_RPMS=$(ls -1 *.rpm | wc -l)
                    echo -e "${YELLOW}Found $TOTAL_RPMS RPM packages to install${NC}"
                    
                    # CRITICAL: Install all RPMs at once - this is essential for dependency resolution
                    # Use rpm directly to avoid any repository access (we're always in offline mode here)
                    echo -e "${YELLOW}  Using rpm to install from local packages only${NC}"
                    
                    if sudo rpm -Uvh --replacepkgs *.rpm 2>&1 | tee /tmp/rpm_install.log; then
                        echo -e "${GREEN}✓ All packages installed successfully${NC}"
                    else
                        # Check the error - might be that packages are already installed
                        if grep -q "already installed" /tmp/rpm_install.log; then
                            echo -e "${GREEN}✓ Packages are already installed${NC}"
                        else
                            echo -e "${RED}✗ Package installation failed${NC}"
                            echo -e "${YELLOW}This usually means the offline archive is missing dependencies.${NC}"
                            echo -e "${YELLOW}Please run prepare_offline.sh again to capture all dependencies.${NC}"
                            
                            # Show which dependencies are missing
                            echo -e "${YELLOW}Missing dependencies:${NC}"
                            grep -E "is needed by|Failed dependencies" /tmp/rpm_install.log | head -20 || true
                            
                            exit 1
                        fi
                    fi
                    
                    # Verify critical packages are actually installed and functional
                    echo -e "${YELLOW}Verifying critical packages...${NC}"
                    CRITICAL_VERIFY=("podman" "ansible" "git")
                    
                    for cmd in "${CRITICAL_VERIFY[@]}"; do
                        if command -v "$cmd" >/dev/null 2>&1; then
                            VERSION=$($cmd --version 2>&1 | head -1)
                            echo -e "${GREEN}✓ $cmd is accessible: $VERSION${NC}"
                        else
                            echo -e "${RED}✗ CRITICAL: $cmd is not accessible after installation${NC}"
                            echo -e "${YELLOW}Checking if RPM is installed...${NC}"
                            rpm -qa | grep -i "$cmd" || echo "Not found in RPM database"
                            exit 1
                        fi
                    done
                    
                    echo -e "${GREEN}✓ Package installation and verification complete!${NC}"
                else
                    # For DEB packages on Ubuntu, use smart installation with proper ordering
                    echo -e "${YELLOW}Installing DEB packages with dependency-aware ordering...${NC}"

                    # CRITICAL: Create nix-users group BEFORE installing nix packages
                    # This prevents systemd errors during package installation
                    echo -e "${YELLOW}Pre-creating nix-users group...${NC}"
                    if ! getent group nix-users >/dev/null 2>&1; then
                        sudo groupadd -r nix-users
                        echo -e "${GREEN}✓ Created nix-users group${NC}"
                    else
                        echo -e "${GREEN}✓ nix-users group already exists${NC}"
                    fi

                    # Install packages in phases to handle dependencies properly
                    # Phase 1: Install base system packages (skip conflicts with system packages)
                    echo -e "${YELLOW}Phase 1: Installing base system packages...${NC}"
                    for deb_file in *.deb; do
                        PACKAGE_NAME=$(dpkg-deb -f "$deb_file" Package 2>/dev/null)

                        # Skip nix packages in this phase
                        if [[ "$PACKAGE_NAME" == "nix-bin" ]] || [[ "$PACKAGE_NAME" == "nix-setup-systemd" ]]; then
                            continue
                        fi

                        # Skip packages that conflict with Ubuntu 24.04 system packages
                        # These are typically already installed or have newer versions
                        if [[ "$PACKAGE_NAME" =~ ^(libqt5|opensysusers|systemd-standalone) ]]; then
                            echo -e "${YELLOW}  Skipping $PACKAGE_NAME (conflicts with system package)${NC}"
                            continue
                        fi

                        # Check if package is already installed
                        if dpkg -l "$PACKAGE_NAME" 2>/dev/null | grep -q "^ii"; then
                            echo -e "${GREEN}  ✓ $PACKAGE_NAME already installed${NC}"
                            continue
                        fi

                        # Try to install the package
                        echo -e "${YELLOW}  Installing $PACKAGE_NAME...${NC}"
                        if sudo dpkg -i "$deb_file" 2>&1 | tee /tmp/dpkg_install.log; then
                            echo -e "${GREEN}  ✓ Installed $PACKAGE_NAME${NC}"
                        else
                            # Check if it failed due to conflict
                            if grep -q "conflicting packages\|conflicts with" /tmp/dpkg_install.log; then
                                echo -e "${YELLOW}  ⚠ Skipping $PACKAGE_NAME (conflicts with existing package)${NC}"
                                continue
                            fi

                            # For other errors, continue but note them
                            echo -e "${YELLOW}  ⚠ Warning installing $PACKAGE_NAME, will fix dependencies later${NC}"
                        fi
                    done

                    # Fix any dependency issues from phase 1
                    echo -e "${YELLOW}Fixing dependencies from phase 1...${NC}"
                    sudo apt-get install -f -y 2>&1 | grep -v "0 upgraded, 0 newly installed" || true

                    # Phase 2: Install nix packages (now that nix-users group exists)
                    echo -e "${YELLOW}Phase 2: Installing Nix packages...${NC}"
                    for deb_file in nix-bin*.deb nix-setup-systemd*.deb; do
                        if [ ! -f "$deb_file" ]; then
                            continue
                        fi

                        PACKAGE_NAME=$(dpkg-deb -f "$deb_file" Package 2>/dev/null)

                        # Check if package is already installed
                        if dpkg -l "$PACKAGE_NAME" 2>/dev/null | grep -q "^ii"; then
                            echo -e "${GREEN}  ✓ $PACKAGE_NAME already installed${NC}"
                            continue
                        fi

                        echo -e "${YELLOW}  Installing $PACKAGE_NAME...${NC}"
                        if sudo dpkg -i "$deb_file" 2>&1; then
                            echo -e "${GREEN}  ✓ Installed $PACKAGE_NAME${NC}"
                        else
                            echo -e "${YELLOW}  ⚠ Warning installing $PACKAGE_NAME, will fix dependencies${NC}"
                        fi
                    done

                    # Final dependency fix
                    echo -e "${YELLOW}Final dependency resolution...${NC}"
                    sudo apt-get install -f -y

                    echo -e "${GREEN}✓ Package installation complete!${NC}"
                fi
            else
                echo -e "${RED}✗ No .$PACKAGE_EXT files found in $PACKAGES_DIR directory${NC}"
                exit 1
            fi
        fi

        # Note: Container loading will happen AFTER Ansible installs Nix and podman
        echo -e "${YELLOW}Container images will be loaded after Nix and podman installation${NC}"

        # Setup CVE database for offline Wazuh vulnerability detection
        echo -e "${YELLOW}Setting up CVE database for offline vulnerability detection...${NC}"
        if [ -f "$SCRIPT_DIR/offline_resources/cve/cves.zip" ]; then
            sudo mkdir -p /opt/lme/cve
            sudo cp "$SCRIPT_DIR/offline_resources/cve/cves.zip" /opt/lme/cve/
            sudo chown root:root /opt/lme/cve/cves.zip
            sudo chmod 644 /opt/lme/cve/cves.zip
            echo -e "${GREEN}✓ CVE database copied to /opt/lme/cve/cves.zip${NC}"

            # Configure Wazuh to use offline CVE database
            echo -e "${YELLOW}Configuring Wazuh for offline CVE database...${NC}"
            if [ -f "$SCRIPT_DIR/config/wazuh_cluster/wazuh_manager.conf" ]; then
                # Create backup
                sudo cp "$SCRIPT_DIR/config/wazuh_cluster/wazuh_manager.conf" "$SCRIPT_DIR/config/wazuh_cluster/wazuh_manager.conf.backup.$(date +%Y%m%d-%H%M%S)"

                # Add offline-url to vulnerability-detection section if not already present
                if ! grep -q "offline-url" "$SCRIPT_DIR/config/wazuh_cluster/wazuh_manager.conf"; then
                    # Use awk to insert the offline-url line after feed-update-interval
                    awk '/feed-update-interval>60m<\/feed-update-interval>/ { print; print "     <offline-url>file:///opt/lme/cve/cves.zip</offline-url>"; next } 1' "$SCRIPT_DIR/config/wazuh_cluster/wazuh_manager.conf" > /tmp/wazuh_manager_temp.conf
                    sudo mv /tmp/wazuh_manager_temp.conf "$SCRIPT_DIR/config/wazuh_cluster/wazuh_manager.conf"
                    echo -e "${GREEN}✓ Wazuh configuration updated for offline CVE database${NC}"
                else
                    echo -e "${GREEN}✓ Wazuh configuration already contains offline CVE database setting${NC}"
                fi
            else
                echo -e "${RED}✗ Wazuh configuration file not found${NC}"
            fi

            # Add CVE database volume mount to Wazuh container
            echo -e "${YELLOW}Adding CVE database volume mount to Wazuh container...${NC}"
            WAZUH_CONTAINER_FILE="$SCRIPT_DIR/quadlet/lme-wazuh-manager.container"
            if [ -f "$WAZUH_CONTAINER_FILE" ]; then
                # Create backup
                sudo cp "$WAZUH_CONTAINER_FILE" "$WAZUH_CONTAINER_FILE.backup.$(date +%Y%m%d-%H%M%S)"

                # Add CVE volume mount if not already present
                if ! grep -q "Volume=/opt/lme/cve" "$WAZUH_CONTAINER_FILE"; then
                    # Use awk to insert the CVE volume mount after the ca-certificates line
                    awk '/Volume=.*ca-certificates.crt:ro/ { print; print "Volume=/opt/lme/cve:/opt/lme/cve:ro"; next } 1' "$WAZUH_CONTAINER_FILE" > /tmp/wazuh_container_temp.conf
                    sudo mv /tmp/wazuh_container_temp.conf "$WAZUH_CONTAINER_FILE"
                    echo -e "${GREEN}✓ CVE database volume mount added to Wazuh container${NC}"
                else
                    echo -e "${GREEN}✓ CVE database volume mount already present in Wazuh container${NC}"
                fi
            else
                echo -e "${RED}✗ Wazuh container file not found${NC}"
            fi
        else
            echo -e "${YELLOW}⚠ CVE database not found in offline resources, skipping${NC}"
        fi

        # Note: Kibana offline configuration is handled by Ansible in the fleet role
        # The fleet role will add xpack.fleet.registryUrl and xpack.fleet.isAirGapped
        # to /opt/lme/config/kibana.yml after it's copied from the source

        # Configure Kibana container to use only local CA in offline mode
        echo -e "${YELLOW}Configuring Kibana container for offline CA trust...${NC}"
        KIBANA_CONTAINER_FILE="$SCRIPT_DIR/quadlet/lme-kibana.container"

        if [ -f "$KIBANA_CONTAINER_FILE" ]; then
            # Replace NODE_EXTRA_CA_CERTS to use only local CA
            sed -i 's|NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt|NODE_EXTRA_CA_CERTS=/usr/share/kibana/config/certs/ca/ca.crt|g' "$KIBANA_CONTAINER_FILE"
            echo -e "${GREEN}✓ Kibana container configured to trust only local CA${NC}"
        else
            echo -e "${RED}✗ Kibana container file not found${NC}"
        fi

        # Configure all container files for offline mode (add Pull=never)
        echo -e "${YELLOW}Configuring container files for offline mode...${NC}"
        for container_file in "$SCRIPT_DIR/quadlet"/*.container; do
            if [ -f "$container_file" ] && ! grep -q "Pull=never" "$container_file"; then
                # Add Pull=never after the Image= line
                sed -i '/^Image=/a Pull=never' "$container_file"
                echo -e "${GREEN}✓ Configured $(basename "$container_file") for offline mode${NC}"
            fi
        done

        # Create offline mode marker files
        echo -e "${YELLOW}Creating offline mode marker files...${NC}"
        sudo mkdir -p /opt/lme
        sudo touch /opt/lme/OFFLINE_MODE
        sudo touch /opt/lme/FLEET_SETUP_FINISHED

        echo -e "${GREEN}✓ Offline resources prepared successfully${NC}"
fi

# Check sudo access first
check_sudo_access

# Check if script is run with sufficient permissions
if [[ $EUID -ne 0 && "$DISTRO" != "alpine" ]]; then
    echo -e "${YELLOW}Note: You will need sudo privileges to install packages.${NC}"
fi

# Get machine IP addresses
get_ip_addresses
echo -e "${GREEN}Final IP address to use: ${IPVAR:-Unknown}${NC}"

# Check if lme-environment.env exists
if [ -f "$SCRIPT_DIR/config/lme-environment.env" ]; then
    echo -e "${GREEN}✓ lme-environment.env already exists, skipping creation${NC}"
else
    if [ "$NON_INTERACTIVE" = "true" ]; then
        if [ "$AUTO_CREATE_ENV" = "true" ]; then
            echo -e "${YELLOW}Creating environment file in non-interactive mode...${NC}"
            cp "$SCRIPT_DIR/config/example.env" "$SCRIPT_DIR/config/lme-environment.env"
            if [ $? -eq 0 ]; then
                # Use sed to replace the IPVAR line with the new IP
                sed -i "s/IPVAR=.*/IPVAR=${IPVAR}/" "$SCRIPT_DIR/config/lme-environment.env"
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}✓ Successfully created and updated environment file${NC}"
                else
                    echo -e "${RED}Failed to update IP in environment file${NC}"
                    exit 1
                fi
            else
                echo -e "${RED}Failed to copy example.env to lme-environment.env${NC}"
                exit 1
            fi
        else
            echo -e "${RED}No valid lme-environment.env file found and AUTO_CREATE_ENV is not set to true.${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}No lme-environment.env found. Would you like to create one from example.env? (y/n)${NC}"
        read -p "> " confirm
        if [[ $confirm =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Creating environment file...${NC}"
            cp "$SCRIPT_DIR/config/example.env" "$SCRIPT_DIR/config/lme-environment.env"
            if [ $? -eq 0 ]; then
                # Use sed to replace the IPVAR line with the new IP
                sed -i "s/IPVAR=.*/IPVAR=${IPVAR}/" "$SCRIPT_DIR/config/lme-environment.env"
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}✓ Successfully created and updated environment file${NC}"
                else
                    echo -e "${RED}Failed to update IP in environment file${NC}"
                    exit 1
                fi
            else
                echo -e "${RED}Failed to copy example.env to lme-environment.env${NC}"
                exit 1
            fi
        else
            echo -e "${RED}No valid lme-environment.env file found. Please create one from example.env before running this script, or allow the script to create one for you.${NC}"
            exit 1
        fi
    fi
fi

# Check if ansible is already installed
check_ansible
if [ $? -ne 0 ]; then
    # In offline mode, ansible must be pre-installed
    if [ "$OFFLINE_MODE" = "true" ]; then
        echo -e "${RED}✗ Ansible is required but not installed.${NC}"
        echo -e "${YELLOW}In offline mode, Ansible must be pre-installed.${NC}"
        echo -e "${YELLOW}Please install Ansible manually:${NC}"
        echo -e "${YELLOW}  For Ubuntu/Debian: sudo apt-get install ansible${NC}"
        echo -e "${YELLOW}  For RHEL/CentOS: sudo dnf install ansible${NC}"
        exit 1
    fi

    # Detect distribution and install ansible
    detect_distro
    install_ansible

    # Verify installation
    if ! check_ansible; then
        echo -e "${RED}Failed to verify Ansible installation. Please install manually.${NC}"
        exit 1
    fi
fi

# Check if playbook exists and run it
check_playbook

# Import podman from .nar file BEFORE running Ansible (Ubuntu offline only)
if [ "$OFFLINE_MODE" = "true" ]; then
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID="$ID"
    else
        OS_ID="unknown"
    fi

    # Only for Ubuntu/Debian offline - import podman from .nar file
    if [[ ! "$OS_ID" =~ ^(rhel|centos|rocky|almalinux|fedora)$ ]]; then
        NIX_PODMAN_NAR="$SCRIPT_DIR/offline_resources/packages/nix/podman-closure.nar"
        if [ -f "$NIX_PODMAN_NAR" ]; then
            echo -e "${YELLOW}Importing podman into Nix store from offline archive...${NC}"
            export PATH=$PATH:/nix/var/nix/profiles/default/bin

            # CRITICAL: Create nixbld group and build users for multi-user Nix
            # The nix-bin and nix-setup-systemd packages don't create these automatically
            echo -e "${YELLOW}Setting up Nix build users and group...${NC}"
            if ! getent group nixbld >/dev/null 2>&1; then
                sudo groupadd -r nixbld
                echo -e "${GREEN}✓ Created nixbld group${NC}"
            else
                echo -e "${GREEN}✓ nixbld group already exists${NC}"
            fi

            # Create nixbld users (nixbld1 through nixbld32)
            for i in $(seq 1 32); do
                if ! id -u nixbld$i >/dev/null 2>&1; then
                    sudo useradd -r -g nixbld -G nixbld -d /var/empty -s /sbin/nologin -c "Nix build user $i" nixbld$i 2>/dev/null || true
                fi
            done
            echo -e "${GREEN}✓ Nix build users configured${NC}"

            # Import the podman closure
            if sudo nix-store --import < "$NIX_PODMAN_NAR"; then
                echo -e "${GREEN}✓ Podman imported into Nix store${NC}"

                # Get the podman store path
                PODMAN_STORE_PATH=$(cat "$SCRIPT_DIR/offline_resources/packages/nix/podman-store-path.txt")

                # Install podman into the default profile
                echo -e "${YELLOW}Installing podman into Nix profile...${NC}"
                if sudo nix-env -i "$PODMAN_STORE_PATH"; then
                    echo -e "${GREEN}✓ Podman installed into Nix profile${NC}"

                    # Verify podman is accessible
                    if [ -x /nix/var/nix/profiles/default/bin/podman ]; then
                        PODMAN_VERSION=$(/nix/var/nix/profiles/default/bin/podman --version)
                        echo -e "${GREEN}✓ Podman is accessible: $PODMAN_VERSION${NC}"
                    else
                        echo -e "${RED}✗ Podman installed but not found in Nix profile${NC}"
                        exit 1
                    fi
                else
                    echo -e "${RED}✗ Failed to install podman into Nix profile${NC}"
                    exit 1
                fi
            else
                echo -e "${RED}✗ Failed to import podman from .nar file${NC}"
                exit 1
            fi
        else
            echo -e "${RED}✗ Podman .nar file not found: $NIX_PODMAN_NAR${NC}"
            echo -e "${YELLOW}Please run prepare_offline.sh to generate offline resources${NC}"
            exit 1
        fi
    fi
fi

# Run the Ansible playbook FIRST (installs Nix and podman)
run_playbook

# Load containers for offline mode AFTER Ansible playbook completes
if [ "$OFFLINE_MODE" = "true" ]; then
    echo -e "${YELLOW}Loading container images for offline installation...${NC}"

    # Detect OS for podman path handling
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID="$ID"
    else
        OS_ID="unknown"
    fi

    # Set PATH based on OS and installation method
    if [[ "$OS_ID" =~ ^(rhel|centos|rocky|almalinux|fedora)$ ]]; then
        # RHEL offline uses system podman
        echo -e "${GREEN}Using system podman (RHEL offline mode)${NC}"
        PODMAN_CHECK_CMD="command -v podman"
        PODMAN_VERSION_CMD="podman --version"
        PODMAN_WHICH_CMD="which podman"
        PODMAN_IMAGES_CMD="podman images --format '{{.Repository}}'"
    else
        # Ubuntu/Debian offline uses Nix podman
        export PATH="/nix/var/nix/profiles/default/bin:$PATH"
        echo -e "${GREEN}Using Nix podman (Ubuntu/Debian offline mode)${NC}"
        PODMAN_CHECK_CMD="export PATH=/nix/var/nix/profiles/default/bin:\$PATH; command -v podman"
        PODMAN_VERSION_CMD="export PATH=/nix/var/nix/profiles/default/bin:\$PATH; podman --version"
        PODMAN_WHICH_CMD="export PATH=/nix/var/nix/profiles/default/bin:\$PATH; which podman"
        PODMAN_IMAGES_CMD="export PATH=/nix/var/nix/profiles/default/bin:\$PATH; podman images --format '{{.Repository}}'"
    fi

    # Debug: Show current PATH and environment
    if [ "$DEBUG_MODE" = "true" ]; then
        echo -e "${YELLOW}Debug: Current PATH: $PATH${NC}"
        echo -e "${YELLOW}Debug: Checking podman locations:${NC}"
        echo -e "${YELLOW}  /nix/var/nix/profiles/default/bin/podman: $(test -x /nix/var/nix/profiles/default/bin/podman && echo 'Found' || echo 'Not found')${NC}"
        echo -e "${YELLOW}  /usr/bin/podman: $(test -x /usr/bin/podman && echo 'Found' || echo 'Not found')${NC}"
        echo -e "${YELLOW}  /usr/local/bin/podman: $(test -x /usr/local/bin/podman && echo 'Found' || echo 'Not found')${NC}"
    fi

    # Verify podman is now available
    echo -e "${YELLOW}Verifying podman installation...${NC}"
    if sudo bash -c "$PODMAN_CHECK_CMD" >/dev/null 2>&1; then
        PODMAN_VERSION=$(sudo bash -c "$PODMAN_VERSION_CMD")
        PODMAN_LOCATION=$(sudo bash -c "$PODMAN_WHICH_CMD")
        echo -e "${GREEN}✓ Podman is available: $PODMAN_VERSION${NC}"
        echo -e "${GREEN}✓ Podman location: $PODMAN_LOCATION${NC}"

        # Check if containers are already loaded
        if sudo bash -c "$PODMAN_IMAGES_CMD" | grep -q "localhost\|docker\." > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Container images already loaded, skipping container loading${NC}"
        else
            # Load containers
            cd "$SCRIPT_DIR/offline_resources"
            if [ -f "$SCRIPT_DIR/offline_resources/load_containers.sh" ]; then
                echo -e "${YELLOW}Running container loading script...${NC}"
                "$SCRIPT_DIR/offline_resources/load_containers.sh"
                if [ $? -ne 0 ]; then
                    echo -e "${RED}✗ Container loading failed${NC}"
                    exit 1
                fi
                echo -e "${GREEN}✓ Container images loaded successfully${NC}"
            else
                echo -e "${RED}✗ Container loading script not found${NC}"
                exit 1
            fi
            cd "$SCRIPT_DIR"
        fi
    else
        echo -e "${RED}✗ Podman is not available after Ansible installation${NC}"
        echo -e "${YELLOW}Troubleshooting steps:${NC}"
        if [[ "$OS_ID" =~ ^(rhel|centos|rocky|almalinux|fedora)$ ]]; then
            echo -e "${YELLOW}1. Check if podman RPM is installed: rpm -qa | grep podman${NC}"
            echo -e "${YELLOW}2. Try running: sudo podman --version${NC}"
            echo -e "${YELLOW}3. Check if podman binary exists: ls -la /usr/bin/podman${NC}"
            echo -e "${YELLOW}4. Reinstall podman: sudo dnf reinstall podman${NC}"
        else
            echo -e "${YELLOW}1. Check if Nix is installed: ls -la /nix/var/nix/profiles/default/bin/podman${NC}"
            echo -e "${YELLOW}2. Try running: sudo -i podman --version${NC}"
            echo -e "${YELLOW}3. Check Ansible logs for Nix/podman installation errors${NC}"
        fi
        echo -e "${YELLOW}4. Verify offline resources: $SCRIPT_DIR/scripts/validate_offline_archive.sh -d $SCRIPT_DIR/offline_resources${NC}"

        # Additional debugging information
        echo -e "${YELLOW}Debug information:${NC}"
        echo -e "${YELLOW}  Current PATH: $PATH${NC}"
        echo -e "${YELLOW}  Nix directory exists: $(test -d /nix && echo 'Yes' || echo 'No')${NC}"
        echo -e "${YELLOW}  Nix profiles directory: $(test -d /nix/var/nix/profiles && echo 'Yes' || echo 'No')${NC}"
        echo -e "${YELLOW}  Default profile: $(test -d /nix/var/nix/profiles/default && echo 'Yes' || echo 'No')${NC}"
        echo -e "${YELLOW}  Offline resources: $(test -d $SCRIPT_DIR/offline_resources && echo 'Yes' || echo 'No')${NC}"
        echo -e "${YELLOW}  System podman: $(test -x /usr/bin/podman && echo 'Yes' || echo 'No')${NC}"

        exit 1
    fi
fi

echo -e "${GREEN}All operations completed successfully!${NC}"
exit 0