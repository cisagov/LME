#!/bin/bash
# LME Red Hat Firewall Configuration Script
# This script automatically detects and configures firewalld rules for LME
# Compatible with Red Hat Enterprise Linux, CentOS, and Fedora systems
#
# REQUIRES ROOT ACCESS - Run as: sudo ./configure_rhel_firewall.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root - required for firewall configuration
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[ERROR]${NC} This script must be run as root"
   echo "Please run: sudo $0"
   exit 1
fi

# Function to check if firewalld is installed and running
check_firewalld() {
    log_info "Checking firewalld status..."
    
    # Check if firewalld is installed
    if ! command -v firewall-cmd &> /dev/null; then
        log_error "firewalld is not installed. Installing..."
        # Support multiple package managers
        if command -v dnf &> /dev/null; then
            dnf install -y firewalld
        elif command -v yum &> /dev/null; then
            yum install -y firewalld
        elif command -v zypper &> /dev/null; then
            zypper install -y firewalld
        elif command -v apt &> /dev/null; then
            apt update && apt install -y firewalld
        else
            log_error "Could not install firewalld automatically. Please install firewalld manually."
            exit 1
        fi
    fi
    
    # Check if firewalld service is running
    if ! systemctl is-active --quiet firewalld; then
        log_warning "firewalld is not running. Starting..."
        systemctl enable --now firewalld
    fi
    
    # Verify firewalld is responding
    if ! firewall-cmd --state &> /dev/null; then
        log_error "firewalld is not responding properly"
        exit 1
    fi
    
    log_success "firewalld is installed and running"
}

# Function to check dependencies
check_dependencies() {
    log_info "Checking dependencies..."
    
    # Check if podman is installed
    if ! command -v podman &> /dev/null; then
        log_error "podman is not installed or not in PATH"
        log_error "Please install podman before running this script"
        exit 1
    fi
    
    # Check if jq is installed (needed for network inspection)
    if ! command -v jq &> /dev/null; then
        log_warning "jq is not installed. Installing jq for network detection..."
        # Support multiple package managers
        if command -v dnf &> /dev/null; then
            dnf install -y jq
        elif command -v yum &> /dev/null; then
            yum install -y jq
        elif command -v zypper &> /dev/null; then
            zypper install -y jq
        elif command -v apt &> /dev/null; then
            apt update && apt install -y jq
        else
            log_error "Could not install jq automatically. Please install jq manually."
            exit 1
        fi
    fi
    
    log_success "All dependencies are available"
}

# Function to detect LME container network
detect_lme_network() {
    log_info "Detecting LME container network..."
    
    # Try to get LME network information
    local lme_subnet
    if lme_subnet=$(podman network inspect lme 2>/dev/null | jq -r '.[].subnets[].subnet' 2>/dev/null); then
        if [[ -n "$lme_subnet" && "$lme_subnet" != "null" ]]; then
            echo "$lme_subnet"
            return 0
        fi
    fi
    
    log_warning "Could not detect LME network. LME containers may not be running."
    log_info "Default podman subnet 10.88.0.0/16 will be used as fallback"
    echo "10.88.0.0/16"
    return 0
}

# Function to detect podman interfaces
detect_podman_interfaces() {
    log_info "Detecting podman network interfaces..."
    
    local interfaces=()
    
    # Try to get LME network interface (most important)
    local lme_interface
    if lme_interface=$(podman network inspect lme 2>/dev/null | jq -r '.[].network_interface' 2>/dev/null); then
        if [[ -n "$lme_interface" && "$lme_interface" != "null" ]]; then
            interfaces+=("$lme_interface")
            log_info "Found LME network interface: $lme_interface"
        fi
    fi
    
    # Comprehensive interface detection - look for all podman-related interfaces
    local detected_interfaces
    detected_interfaces=$(ip link show | grep -E '^[0-9]+:' | awk -F': ' '{print $2}' | grep -E '^(podman|cni-podman|veth.*podman|br-.*)')
    
    while IFS= read -r iface; do
        if [[ -n "$iface" ]]; then
            # Remove any trailing @ and interface suffix (e.g., podman1@if2 -> podman1)
            iface=$(echo "$iface" | cut -d'@' -f1)
            
            # Check if this interface is already in our list
            local already_added=false
            for existing in "${interfaces[@]}"; do
                if [[ "$existing" == "$iface" ]]; then
                    already_added=true
                    break
                fi
            done
            
            if [[ "$already_added" == false ]]; then
                interfaces+=("$iface")
                log_info "Found podman interface: $iface"
            fi
        fi
    done <<< "$detected_interfaces"
    
    # Also check for common interface names as fallback
    for iface in podman0 podman1 podman2 podman3 cni-podman0 cni-podman1; do
        if ip link show "$iface" &> /dev/null; then
            # Check if this interface is already in our list
            local already_added=false
            for existing in "${interfaces[@]}"; do
                if [[ "$existing" == "$iface" ]]; then
                    already_added=true
                    break
                fi
            done
            
            if [[ "$already_added" == false ]]; then
                interfaces+=("$iface")
                log_info "Found additional podman interface: $iface"
            fi
        fi
    done
    
    if [[ ${#interfaces[@]} -eq 0 ]]; then
        log_warning "No podman interfaces detected. Container networking may not be configured."
        log_warning "Firewall rules will still be applied for external access"
        # Return empty string to prevent array issues
        echo ""
    else
        printf '%s\n' "${interfaces[@]}"
    fi
}

# Function to configure firewall rules
configure_firewall() {
    local lme_subnet="$1"
    local interfaces=("${@:2}")
    
    log_info "Configuring firewall rules for LME..."
    
    # Add LME ports to public zone
    local lme_ports=(1514 1515 8220 9200 5601 443)
    
    log_info "Adding LME ports to public zone..."
    for port in "${lme_ports[@]}"; do
        if firewall-cmd --permanent --zone=public --add-port="${port}/tcp" &> /dev/null; then
            log_success "Added port ${port}/tcp to public zone"
        else
            log_warning "Port ${port}/tcp may already be configured"
        fi
    done
    
    # Optional: Add Wazuh API port
    read -p "Do you want to enable Wazuh API port 55000? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if firewall-cmd --permanent --zone=public --add-port=55000/tcp &> /dev/null; then
            log_success "Added Wazuh API port 55000/tcp to public zone"
        else
            log_warning "Port 55000/tcp may already be configured"
        fi
    fi
    
    # Configure container networking
    log_info "Configuring container networking..."
    
    # Add container subnet to trusted zone
    if [[ -n "$lme_subnet" ]]; then
        if firewall-cmd --permanent --zone=trusted --add-source="$lme_subnet" &> /dev/null; then
            log_success "Added container subnet $lme_subnet to trusted zone"
        else
            log_warning "Container subnet $lme_subnet may already be configured"
        fi
    fi
    
    # Add podman interfaces to trusted zone (if any were detected)
    if [[ ${#interfaces[@]} -gt 0 && -n "${interfaces[0]}" ]]; then
        for iface in "${interfaces[@]}"; do
            if [[ -n "$iface" ]]; then
                if firewall-cmd --permanent --zone=trusted --add-interface="$iface" &> /dev/null; then
                    log_success "Added interface $iface to trusted zone"
                else
                    log_warning "Interface $iface may already be configured"
                fi
            fi
        done
    else
        log_warning "No podman interfaces to configure - container networking may need manual setup"
    fi
    
    # Enable masquerading for container traffic
    if firewall-cmd --permanent --add-masquerade &> /dev/null; then
        log_success "Enabled masquerading for container traffic"
    else
        log_warning "Masquerading may already be enabled"
    fi
    
    # Reload firewall to apply changes
    log_info "Reloading firewall configuration..."
    firewall-cmd --reload
    log_success "Firewall configuration reloaded"
}

# Function to verify configuration
verify_configuration() {
    log_info "Verifying firewall configuration..."
    
    echo
    echo "=== Current Firewall Configuration ==="
    echo
    
    echo "Public Zone (External Access):"
    firewall-cmd --zone=public --list-ports
    echo
    
    echo "Trusted Zone (Container Networks):"
    firewall-cmd --zone=trusted --list-all
    echo
    
    echo "=== Active Zones ==="
    firewall-cmd --get-active-zones
    echo
}

# Function to provide troubleshooting information
provide_troubleshooting() {
    log_info "Troubleshooting Information:"
    echo
    echo "If you experience connectivity issues:"
    echo "1. Check if LME containers are running:"
    echo "   podman ps"
    echo
    echo "2. Test container-to-container communication:"
    echo "   podman exec lme-kibana curl -s http://lme-elasticsearch:9200/_cluster/health"
    echo
    echo "3. Test external access (replace with your server IP):"
    echo "   curl -v http://YOUR_SERVER_IP:5601"
    echo
    echo "4. Check firewall logs for blocked connections:"
    echo "   journalctl -u firewalld | tail -20"
    echo
    echo "5. Temporarily disable firewall for testing:"
    echo "   systemctl stop firewalld"
    echo "   # Test your connections"
    echo "   systemctl start firewalld"
    echo
}

# Main execution
main() {
    echo "========================================"
    echo "LME Red Hat Firewall Configuration"
    echo "========================================"
    echo
    
    # Check prerequisites
    check_firewalld
    
    # Check dependencies first
    check_dependencies
    
    # Detect network configuration
    lme_subnet=$(detect_lme_network)
    
    # Safely handle interface detection
    local interface_output
    interface_output=$(detect_podman_interfaces)
    
    # Create interfaces array, handling empty output
    local interfaces=()
    if [[ -n "$interface_output" ]]; then
        readarray -t interfaces <<< "$interface_output"
    fi
    
    # Display detected configuration
    echo
    log_info "Detected Configuration:"
    echo "  LME Container Subnet: $lme_subnet"
    if [[ ${#interfaces[@]} -gt 0 && -n "${interfaces[0]}" ]]; then
        echo "  Podman Interfaces: ${interfaces[*]}"
    else
        echo "  Podman Interfaces: None detected"
    fi
    echo
    
    # Confirm before proceeding
    read -p "Do you want to configure firewalld with these settings? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Configuration cancelled by user"
        exit 0
    fi
    
    # Configure firewall - handle empty interface array safely
    if [[ ${#interfaces[@]} -gt 0 && -n "${interfaces[0]}" ]]; then
        configure_firewall "$lme_subnet" "${interfaces[@]}"
    else
        configure_firewall "$lme_subnet"
    fi
    
    # Verify configuration
    verify_configuration
    
    # Provide troubleshooting info
    provide_troubleshooting
    
    log_success "LME firewall configuration completed!"
    
    # Recommend restart for complete activation
    echo
    log_warning "⚠️  IMPORTANT: System restart recommended for complete firewall activation"
    echo "After applying firewall configuration changes, it is highly recommended to reboot"
    echo "the machine to ensure all networking and container rules take effect properly."
    echo
    echo "This is especially important for:"
    echo "- Container networking changes - Ensures podman interfaces restart correctly"
    echo "- Firewall rule persistence - Confirms all permanent rules are properly loaded"
    echo "- Network interface binding - Ensures proper interface-to-zone assignments"
    echo "- Service startup order - Guarantees firewall, networking, and containers start correctly"
    echo
    echo "To restart the system:"
    echo "  sudo reboot"
    echo
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
