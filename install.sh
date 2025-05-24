#!/bin/bash

# Colors for better readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default playbook location - can be overridden with command line argument
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PLAYBOOK_PATH="./ansible/site.yml"
CUSTOM_IP=""
HAS_SUDO_ACCESS=""
IPVAR=""
DEBUG_MODE="false"

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
            sudo dnf install -y epel-release
            sudo dnf install -y ansible
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
        ANSIBLE_OPTS="$ANSIBLE_OPTS -e debug_mode=true"
    fi
    
    # Run the main installation playbook
    echo -e "${YELLOW}Running main installation playbook...${NC}"
    if [ -f "./inventory" ]; then
        ansible-playbook -i inventory "$PLAYBOOK_PATH" --extra-vars '{"has_sudo_access":"'"${HAS_SUDO_ACCESS}"'","clone_dir":"'"${SCRIPT_DIR}"'"}' $ANSIBLE_OPTS
    else
        ansible-playbook "$PLAYBOOK_PATH" --extra-vars '{"has_sudo_access":"'"${HAS_SUDO_ACCESS}"'","clone_dir":"'"${SCRIPT_DIR}"'"}' $ANSIBLE_OPTS
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
if [ -f "config/lme-environment.env" ]; then
    echo -e "${GREEN}✓ lme-environment.env already exists, skipping creation${NC}"
else
    if [ "$NON_INTERACTIVE" = "true" ]; then
        if [ "$AUTO_CREATE_ENV" = "true" ]; then
            echo -e "${YELLOW}Creating environment file in non-interactive mode...${NC}"
            cp config/example.env config/lme-environment.env
            if [ $? -eq 0 ]; then
                # Use sed to replace the IPVAR line with the new IP
                sed -i "s/IPVAR=.*/IPVAR=${IPVAR}/" config/lme-environment.env
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
            cp config/example.env config/lme-environment.env
            if [ $? -eq 0 ]; then
                # Use sed to replace the IPVAR line with the new IP
                sed -i "s/IPVAR=.*/IPVAR=${IPVAR}/" config/lme-environment.env
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
run_playbook

echo -e "${GREEN}All operations completed successfully!${NC}"
exit 0