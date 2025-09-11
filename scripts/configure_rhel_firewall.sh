#!/bin/bash
# LME Red Hat Firewall Configuration Script
# This script automatically detects and configures firewalld rules for LME
# Compatible with Red Hat Enterprise Linux, CentOS, and Fedora systems

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

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   SUDO=""
else
   SUDO="sudo"
fi

# Function to check if firewalld is installed and running
check_firewalld() {
    log_info "Checking firewalld status..."
    
    # Check if firewalld is installed
    if ! command -v firewall-cmd &> /dev/null; then
        log_error "firewalld is not installed. Installing..."
        $SUDO dnf install -y firewalld
    fi
    
    # Check if firewalld service is running
    if ! $SUDO systemctl is-active --quiet firewalld; then
        log_warning "firewalld is not running. Starting..."
        $SUDO systemctl enable --now firewalld
    fi
    
    # Verify firewalld is responding
    if ! $SUDO firewall-cmd --state &> /dev/null; then
        log_error "firewalld is not responding properly"
        exit 1
    fi
    
    log_success "firewalld is installed and running"
}

# Function to detect LME container network
detect_lme_network() {
    log_info "Detecting LME container network..."
    
    # Check if podman is installed
    if ! command -v podman &> /dev/null; then
        log_error "podman is not installed or not in PATH"
        return 1
    fi
    
    # Try to get LME network information
    local lme_subnet
    if lme_subnet=$($SUDO -i podman network inspect lme 2>/dev/null | jq -r '.[].subnets[].subnet' 2>/dev/null); then
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
    if lme_interface=$($SUDO -i podman network inspect lme 2>/dev/null | jq -r '.[].network_interface' 2>/dev/null); then
        if [[ -n "$lme_interface" && "$lme_interface" != "null" ]]; then
            interfaces+=("$lme_interface")
            log_info "Found LME network interface: $lme_interface"
        fi
    fi
    
    # Look for common podman interfaces
    for iface in podman0 podman1 cni-podman0 cni-podman1; do
        if ip link show "$iface" &> /dev/null; then
            if [[ ! " ${interfaces[@]} " =~ " ${iface} " ]]; then
                interfaces+=("$iface")
                log_info "Found additional podman interface: $iface"
            fi
        fi
    done
    
    if [[ ${#interfaces[@]} -eq 0 ]]; then
        log_warning "No podman interfaces detected. Container networking may not be configured."
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
        if $SUDO firewall-cmd --permanent --zone=public --add-port="${port}/tcp" &> /dev/null; then
            log_success "Added port ${port}/tcp to public zone"
        else
            log_warning "Port ${port}/tcp may already be configured"
        fi
    done
    
    # Optional: Add Wazuh API port
    read -p "Do you want to enable Wazuh API port 55000? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if $SUDO firewall-cmd --permanent --zone=public --add-port=55000/tcp &> /dev/null; then
            log_success "Added Wazuh API port 55000/tcp to public zone"
        else
            log_warning "Port 55000/tcp may already be configured"
        fi
    fi
    
    # Configure container networking
    log_info "Configuring container networking..."
    
    # Add container subnet to trusted zone
    if [[ -n "$lme_subnet" ]]; then
        if $SUDO firewall-cmd --permanent --zone=trusted --add-source="$lme_subnet" &> /dev/null; then
            log_success "Added container subnet $lme_subnet to trusted zone"
        else
            log_warning "Container subnet $lme_subnet may already be configured"
        fi
    fi
    
    # Add podman interfaces to trusted zone
    for iface in "${interfaces[@]}"; do
        if [[ -n "$iface" ]]; then
            if $SUDO firewall-cmd --permanent --zone=trusted --add-interface="$iface" &> /dev/null; then
                log_success "Added interface $iface to trusted zone"
            else
                log_warning "Interface $iface may already be configured"
            fi
        fi
    done
    
    # Enable masquerading for container traffic
    if $SUDO firewall-cmd --permanent --add-masquerade &> /dev/null; then
        log_success "Enabled masquerading for container traffic"
    else
        log_warning "Masquerading may already be enabled"
    fi
    
    # Reload firewall to apply changes
    log_info "Reloading firewall configuration..."
    $SUDO firewall-cmd --reload
    log_success "Firewall configuration reloaded"
}

# Function to verify configuration
verify_configuration() {
    log_info "Verifying firewall configuration..."
    
    echo
    echo "=== Current Firewall Configuration ==="
    echo
    
    echo "Public Zone (External Access):"
    $SUDO firewall-cmd --zone=public --list-ports
    echo
    
    echo "Trusted Zone (Container Networks):"
    $SUDO firewall-cmd --zone=trusted --list-all
    echo
    
    echo "=== Active Zones ==="
    $SUDO firewall-cmd --get-active-zones
    echo
}

# Function to provide troubleshooting information
provide_troubleshooting() {
    log_info "Troubleshooting Information:"
    echo
    echo "If you experience connectivity issues:"
    echo "1. Check if LME containers are running:"
    echo "   sudo -i podman ps"
    echo
    echo "2. Test container-to-container communication:"
    echo "   sudo -i podman exec lme-kibana curl -s http://lme-elasticsearch:9200/_cluster/health"
    echo
    echo "3. Test external access (replace with your server IP):"
    echo "   curl -v http://YOUR_SERVER_IP:5601"
    echo
    echo "4. Check firewall logs for blocked connections:"
    echo "   sudo journalctl -u firewalld | tail -20"
    echo
    echo "5. Temporarily disable firewall for testing:"
    echo "   sudo systemctl stop firewalld"
    echo "   # Test your connections"
    echo "   sudo systemctl start firewalld"
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
    
    # Detect network configuration
    lme_subnet=$(detect_lme_network)
    readarray -t interfaces <<< "$(detect_podman_interfaces)"
    
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
    
    # Configure firewall
    configure_firewall "$lme_subnet" "${interfaces[@]}"
    
    # Verify configuration
    verify_configuration
    
    # Provide troubleshooting info
    provide_troubleshooting
    
    log_success "LME firewall configuration completed!"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
