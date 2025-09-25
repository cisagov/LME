#!/bin/bash
# LME nftables Configuration Script
# Direct nftables configuration equivalent to the firewalld LME setup
# Compatible with systems that prefer nftables over firewalld
#
# REQUIRES ROOT ACCESS - Run as: sudo ./configure_lme_nftables.sh

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

# Check if running as root - required for nftables configuration
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[ERROR]${NC} This script must be run as root"
   echo "Please run: sudo $0"
   exit 1
fi

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

# Function to check if nftables is available
check_nftables() {
    log_info "Checking nftables availability..."
    
    # Check if nft command exists
    if ! command -v nft &> /dev/null; then
        log_error "nftables is not installed. Installing..."
        # Support multiple package managers
        if command -v dnf &> /dev/null; then
            dnf install -y nftables
        elif command -v yum &> /dev/null; then
            yum install -y nftables
        elif command -v zypper &> /dev/null; then
            zypper install -y nftables
        elif command -v apt &> /dev/null; then
            apt update && apt install -y nftables
        else
            log_error "Could not determine package manager to install nftables"
            exit 1
        fi
    fi
    
    # Ensure nftables service is enabled
    if ! systemctl is-enabled --quiet nftables; then
        log_info "Enabling nftables service..."
        systemctl enable nftables
    fi
    
    log_success "nftables is available"
}

# Function to detect LME container network
detect_lme_network() {
    log_info "Detecting LME container network..." >&2
    
    # Check if podman is installed
    if ! command -v podman &> /dev/null; then
        log_error "podman is not installed or not in PATH" >&2
        return 1
    fi
    
    # Try to get LME network information
    local lme_subnet
    if lme_subnet=$(podman network inspect lme 2>/dev/null | jq -r '.[].subnets[].subnet' 2>/dev/null); then
        if [[ -n "$lme_subnet" && "$lme_subnet" != "null" ]]; then
            echo "$lme_subnet"
            return 0
        fi
    fi
    
    log_warning "Could not detect LME network. Using default podman subnet" >&2
    echo "10.88.0.0/16"
    return 0
}

# Function to detect network interfaces
detect_interfaces() {
    log_info "Detecting network interfaces..." >&2
    
    # Get primary network interface with fallback options
    local primary_iface=""
    
    # Try multiple methods to detect primary interface
    if primary_iface=$(ip route | grep default | head -n1 | awk '{print $5}' 2>/dev/null); then
        if [[ -n "$primary_iface" ]]; then
            log_info "Detected primary interface: $primary_iface" >&2
        fi
    fi
    
    # Fallback: look for common interface names if route detection failed
    if [[ -z "$primary_iface" ]]; then
        for iface in eth0 ens3 ens4 ens5 enp0s3 enp0s8 ens33 ens192; do
            if ip link show "$iface" &> /dev/null; then
                primary_iface="$iface"
                log_warning "Using fallback primary interface: $primary_iface" >&2
                break
            fi
        done
    fi
    
    # Final fallback
    if [[ -z "$primary_iface" ]]; then
        primary_iface="eth0"
        log_warning "Could not detect primary interface, using default: $primary_iface" >&2
    fi
    
    # Comprehensive podman interface detection
    local podman_iface=""
    
    # Try to get LME network interface first (most reliable)
    local lme_interface
    if lme_interface=$(podman network inspect lme 2>/dev/null | jq -r '.[].network_interface' 2>/dev/null); then
        if [[ -n "$lme_interface" && "$lme_interface" != "null" ]]; then
            podman_iface="$lme_interface"
            log_info "Found LME network interface: $podman_iface" >&2
        fi
    fi
    
    # If no LME interface, look for any podman interfaces
    if [[ -z "$podman_iface" ]]; then
        # Look for interfaces with podman-related names
        local detected_podman
        detected_podman=$(ip link show | grep -E '^[0-9]+:' | awk -F': ' '{print $2}' | grep -E '^(podman|cni-podman|veth.*podman|br-.*)' | head -n1)
        
        if [[ -n "$detected_podman" ]]; then
            # Remove any trailing @ and interface suffix
            podman_iface=$(echo "$detected_podman" | cut -d'@' -f1)
            log_info "Found podman interface: $podman_iface" >&2
        else
            # Check common interface names as fallback
            for iface in podman0 podman1 podman2 cni-podman0 cni-podman1; do
                if ip link show "$iface" &> /dev/null; then
                    podman_iface="$iface"
                    log_info "Found podman interface (fallback): $podman_iface" >&2
                    break
                fi
            done
        fi
    fi
    
    if [[ -z "$podman_iface" ]]; then
        log_warning "No podman interface detected - container networking may need manual setup" >&2
    fi
    
    echo "$primary_iface $podman_iface"
}

# Function to backup existing nftables rules
backup_nftables() {
    log_info "Backing up existing nftables configuration..."
    
    local backup_file="/etc/nftables/lme_backup_$(date +%Y%m%d_%H%M%S).nft"
    mkdir -p /etc/nftables
    
    if nft list ruleset > /dev/null 2>&1; then
        nft list ruleset > "$backup_file" || {
            log_warning "Could not create backup, continuing anyway..."
        }
        log_success "Current ruleset backed up to $backup_file"
    fi
}

# Function to create LME nftables configuration
create_lme_nftables() {
    local container_subnet="$1"
    local podman_iface="$2"
    local enable_wazuh_api="$3"
    
    log_info "Creating LME nftables configuration..."
    
    # Create the nftables configuration file
    local config_file="/etc/nftables/lme.nft"
    mkdir -p /etc/nftables
    
    cat > /tmp/lme_nftables.conf << EOF
#!/usr/sbin/nft -f
# LME nftables configuration
# Equivalent to firewalld LME setup

# Flush existing rules (comment out if you want to preserve existing rules)
# flush ruleset

table inet lme_filter {
    # Input chain - handle incoming connections
    chain input {
        type filter hook input priority filter; policy drop;
        
        # Allow loopback traffic
        iifname "lo" accept
        
        # Allow established and related connections
        ct state established,related accept
        
        # Allow ICMP
        ip protocol icmp accept
        ip6 nexthdr ipv6-icmp accept
        
        # Allow SSH (modify port if needed)
        tcp dport 22 accept
        
        # LME service ports - accessible from all interfaces
        tcp dport { 1514, 1515, 8220, 9200, 5601, 443 } accept
        
        # Wazuh syslog UDP port
        udp dport 514 accept
EOF

    # Add Wazuh API port if requested
    if [[ "$enable_wazuh_api" == "yes" ]]; then
        cat >> /tmp/lme_nftables.conf << EOF
        
        # Wazuh API port - accessible from all interfaces
        tcp dport 55000 accept
EOF
    fi

    # Continue with the rest of the configuration
    cat >> /tmp/lme_nftables.conf << EOF
        
        # Allow all traffic from container network
        ip saddr $container_subnet accept
        
        # Allow all traffic on podman interface
EOF

    if [[ -n "$podman_iface" ]]; then
        cat >> /tmp/lme_nftables.conf << EOF
        iifname "$podman_iface" accept
EOF
    fi

    cat >> /tmp/lme_nftables.conf << EOF
        
        # Log and drop everything else
        log prefix "LME_DROPPED: " drop
    }
    
    # Forward chain - handle traffic forwarding
    chain forward {
        type filter hook forward priority filter; policy drop;
        
        # Allow established and related connections
        ct state established,related accept
        
        # Allow forwarding from container network
        ip saddr $container_subnet accept
        
        # Allow forwarding to container network
        ip daddr $container_subnet accept
EOF

    if [[ -n "$podman_iface" ]]; then
        cat >> /tmp/lme_nftables.conf << EOF
        
        # Allow forwarding on podman interface
        iifname "$podman_iface" accept
        oifname "$podman_iface" accept
EOF
    fi

    cat >> /tmp/lme_nftables.conf << EOF
        
        # Log and drop everything else
        log prefix "LME_FWD_DROPPED: " drop
    }
}

table ip lme_nat {
    # NAT chain for masquerading container traffic
    chain postrouting {
        type nat hook postrouting priority srcnat; policy accept;
        
        # Masquerade traffic from container network
        ip saddr $container_subnet masquerade
    }
}
EOF

    # Move the configuration file to its final location
    mv /tmp/lme_nftables.conf "$config_file"
    chmod 644 "$config_file"
    
    # Fix SELinux context if SELinux is enabled
    if command -v restorecon &> /dev/null; then
        restorecon "$config_file" 2>/dev/null || true
        log_info "SELinux context restored for $config_file"
    fi
    
    log_success "nftables configuration created at $config_file"
}

# Function to apply nftables configuration
apply_nftables() {
    local config_file="/etc/nftables/lme.nft"
    
    log_info "Applying nftables configuration..."
    
    # Test the configuration first
    if ! nft -c -f "$config_file"; then
        log_error "nftables configuration has syntax errors"
        return 1
    fi
    
    # Apply the configuration
    nft -f "$config_file"
    log_success "nftables configuration applied"
    
    # Add to main nftables config to persist across reboots
    # Handle different distributions (RHEL uses /etc/sysconfig/nftables.conf)
    local main_config="/etc/nftables.conf"
    if [[ -f "/etc/sysconfig/nftables.conf" ]]; then
        main_config="/etc/sysconfig/nftables.conf"
        log_info "Detected RHEL/CentOS system, using $main_config"
    fi
    
    if [[ -f "$main_config" ]]; then
        if ! grep -q "include.*lme.nft" "$main_config"; then
            echo 'include "/etc/nftables/lme.nft"' | tee -a "$main_config" > /dev/null
            log_success "LME configuration added to main nftables config"
        fi
    else
        # Create main config if it doesn't exist
        echo 'include "/etc/nftables/lme.nft"' | tee "$main_config" > /dev/null
        log_success "Created main nftables config with LME rules"
    fi
    
    # Ensure nftables service will start on boot
    systemctl enable nftables
}

# Function to verify configuration
verify_configuration() {
    log_info "Verifying nftables configuration..."
    
    echo
    echo "=== Current nftables Configuration ==="
    echo
    
    echo "Filter table (lme_filter):"
    nft list table inet lme_filter 2>/dev/null || log_warning "lme_filter table not found"
    echo
    
    echo "NAT table (lme_nat):"
    nft list table ip lme_nat 2>/dev/null || log_warning "lme_nat table not found"
    echo
    
    echo "=== All Active Rules ==="
    nft list ruleset | grep -A 10 -B 2 "lme" || log_info "No LME-specific rules found in output"
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
    echo "4. Check nftables rules:"
    echo "   nft list ruleset"
    echo
    echo "5. Monitor dropped packets:"
    echo "   journalctl -f | grep LME_DROPPED"
    echo
    echo "6. Temporarily flush rules for testing:"
    echo "   nft delete table inet lme_filter"
    echo "   nft delete table ip lme_nat"
    echo "   # Test your connections"
    echo "   nft -f /etc/nftables/lme.nft"
    echo
    echo "7. Restore from backup if needed:"
    echo "   ls -la /etc/nftables/lme_backup_*"
    echo "   nft -f /etc/nftables/lme_backup_YYYYMMDD_HHMMSS.nft"
    echo
}

# Function to disable firewalld if running
disable_firewalld() {
    if systemctl is-active --quiet firewalld; then
        log_warning "firewalld is currently running"
        read -p "Do you want to stop and disable firewalld? (recommended for nftables) (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            systemctl stop firewalld
            systemctl disable firewalld
            log_success "firewalld stopped and disabled"
        else
            log_warning "firewalld is still running - this may conflict with nftables rules"
        fi
    fi
}

# Main execution
main() {
    echo "========================================"
    echo "LME nftables Configuration"
    echo "========================================"
    echo
    
    # Check if firewalld conflicts
    disable_firewalld
    
    # Check dependencies first
    check_dependencies
    
    # Check prerequisites
    check_nftables
    
    # Detect network configuration
    container_subnet=$(detect_lme_network)
    podman_iface=$(detect_interfaces | awk '{print $2}')
    
    # Display detected configuration
    echo
    log_info "Detected Configuration:"
    echo "  Container Subnet: $container_subnet"
    echo "  Podman Interface: ${podman_iface:-"None detected"}"
    echo
    
    # Ask about Wazuh API
    read -p "Do you want to enable Wazuh API port 55000? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        enable_wazuh_api="yes"
    else
        enable_wazuh_api="no"
    fi
    
    # Confirm before proceeding
    read -p "Do you want to configure nftables with these settings? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Configuration cancelled by user"
        exit 0
    fi
    
    # Backup existing configuration
    backup_nftables
    
    # Create and apply nftables configuration
    create_lme_nftables "$container_subnet" "$podman_iface" "$enable_wazuh_api"
    apply_nftables
    
    # Verify configuration
    verify_configuration
    
    # Provide troubleshooting info
    provide_troubleshooting
    
    log_success "LME nftables configuration completed!"
    log_info "Configuration will persist across reboots via /etc/nftables.conf"
    
    # Recommend restart for complete activation
    echo
    log_warning "⚠️  IMPORTANT: System restart recommended for complete nftables activation"
    echo "After applying nftables configuration changes, it is highly recommended to reboot"
    echo "the machine to ensure all networking and container rules take effect properly."
    echo
    echo "This is especially important for:"
    echo "- Container networking changes - Ensures podman interfaces and bridge networks restart correctly"
    echo "- nftables rule persistence - Confirms all rules are properly loaded from configuration files"
    echo "- Network interface binding - Ensures proper interface-to-rule assignments"
    echo "- Service startup order - Guarantees nftables, networking, and containers start in the correct sequence"
    echo
    echo "To restart the system:"
    echo "  sudo reboot"
    echo
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
