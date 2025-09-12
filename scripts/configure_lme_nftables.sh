#!/bin/bash
# LME nftables Configuration Script
# Direct nftables configuration equivalent to the firewalld LME setup
# Compatible with systems that prefer nftables over firewalld

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


# Function to check if nftables is available
check_nftables() {
    log_info "Checking nftables availability..."
    
    # Check if nft command exists
    if ! command -v nft &> /dev/null; then
        log_error "nftables is not installed. Installing..."
        if command -v dnf &> /dev/null; then
            sudo dnf install -y nftables
        elif command -v apt &> /dev/null; then
            sudo apt update && sudo apt install -y nftables
        else
            log_error "Could not determine package manager to install nftables"
            exit 1
        fi
    fi
    
    # Ensure nftables service is enabled
    if ! sudo systemctl is-enabled --quiet nftables; then
        log_info "Enabling nftables service..."
        sudo systemctl enable nftables
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
    if lme_subnet=$(sudo -i podman network inspect lme 2>/dev/null | jq -r '.[].subnets[].subnet' 2>/dev/null); then
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
    
    # Get primary network interface (usually eth0, but could be others)
    local primary_iface
    primary_iface=$(ip route | grep default | head -n1 | awk '{print $5}')
    
    # Get podman interface
    local podman_iface=""
    for iface in podman0 podman1 cni-podman0 cni-podman1; do
        if ip link show "$iface" &> /dev/null; then
            podman_iface="$iface"
            break
        fi
    done
    
    echo "$primary_iface $podman_iface"
}

# Function to backup existing nftables rules
backup_nftables() {
    log_info "Backing up existing nftables configuration..."
    
    local backup_file="/etc/nftables/lme_backup_$(date +%Y%m%d_%H%M%S).nft"
    sudo mkdir -p /etc/nftables
    
    if sudo nft list ruleset > /dev/null 2>&1; then
        sudo nft list ruleset > "$backup_file" || {
            log_warning "Could not create backup, continuing anyway..."
        }
        log_success "Current ruleset backed up to $backup_file"
    fi
}

# Function to create LME nftables configuration
create_lme_nftables() {
    local container_subnet="$1"
    local primary_iface="$2"
    local podman_iface="$3"
    local enable_wazuh_api="$4"
    
    log_info "Creating LME nftables configuration..."
    
    # Create the nftables configuration file
    local config_file="/etc/nftables/lme.nft"
    sudo mkdir -p /etc/nftables
    
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
        
        # LME service ports on primary interface
        iifname "$primary_iface" tcp dport { 1514, 1515, 8220, 9200, 5601, 443 } accept
EOF

    # Add Wazuh API port if requested
    if [[ "$enable_wazuh_api" == "yes" ]]; then
        cat >> /tmp/lme_nftables.conf << EOF
        
        # Wazuh API port
        iifname "$primary_iface" tcp dport 55000 accept
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
        
        # Masquerade traffic from container network going out primary interface
        ip saddr $container_subnet oifname "$primary_iface" masquerade
        
        # General masquerading for container traffic (except loopback)
        oifname != "lo" masquerade
    }
}
EOF

    # Move the configuration file to its final location
    sudo mv /tmp/lme_nftables.conf "$config_file"
    sudo chmod 640 "$config_file"
    
    log_success "nftables configuration created at $config_file"
}

# Function to apply nftables configuration
apply_nftables() {
    local config_file="/etc/nftables/lme.nft"
    
    log_info "Applying nftables configuration..."
    
    # Test the configuration first
    if ! sudo nft -c -f "$config_file"; then
        log_error "nftables configuration has syntax errors"
        return 1
    fi
    
    # Apply the configuration
    sudo nft -f "$config_file"
    log_success "nftables configuration applied"
    
    # Add to main nftables config to persist across reboots
    local main_config="/etc/nftables.conf"
    if [[ -f "$main_config" ]]; then
        if ! grep -q "include.*lme.nft" "$main_config"; then
            echo 'include "/etc/nftables/lme.nft"' | sudo tee -a "$main_config" > /dev/null
            log_success "LME configuration added to main nftables config"
        fi
    else
        # Create main config if it doesn't exist
        echo 'include "/etc/nftables/lme.nft"' | sudo tee "$main_config" > /dev/null
        log_success "Created main nftables config with LME rules"
    fi
    
    # Ensure nftables service will start on boot
    sudo systemctl enable nftables
}

# Function to verify configuration
verify_configuration() {
    log_info "Verifying nftables configuration..."
    
    echo
    echo "=== Current nftables Configuration ==="
    echo
    
    echo "Filter table (lme_filter):"
    sudo nft list table inet lme_filter 2>/dev/null || log_warning "lme_filter table not found"
    echo
    
    echo "NAT table (lme_nat):"
    sudo nft list table ip lme_nat 2>/dev/null || log_warning "lme_nat table not found"
    echo
    
    echo "=== All Active Rules ==="
    sudo nft list ruleset | grep -A 10 -B 2 "lme" || log_info "No LME-specific rules found in output"
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
    echo "4. Check nftables rules:"
    echo "   sudo nft list ruleset"
    echo
    echo "5. Monitor dropped packets:"
    echo "   sudo journalctl -f | grep LME_DROPPED"
    echo
    echo "6. Temporarily flush rules for testing:"
    echo "   sudo nft delete table inet lme_filter"
    echo "   sudo nft delete table ip lme_nat"
    echo "   # Test your connections"
    echo "   sudo nft -f /etc/nftables/lme.nft"
    echo
    echo "7. Restore from backup if needed:"
    echo "   ls -la /etc/nftables/lme_backup_*"
    echo "   sudo nft -f /etc/nftables/lme_backup_YYYYMMDD_HHMMSS.nft"
    echo
}

# Function to disable firewalld if running
disable_firewalld() {
    if systemctl is-active --quiet firewalld; then
        log_warning "firewalld is currently running"
        read -p "Do you want to stop and disable firewalld? (recommended for nftables) (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo systemctl stop firewalld
            sudo systemctl disable firewalld
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
    
    # Check prerequisites
    check_nftables
    
    # Detect network configuration
    container_subnet=$(detect_lme_network)
    read -r primary_iface podman_iface <<< "$(detect_interfaces)"
    
    # Display detected configuration
    echo
    log_info "Detected Configuration:"
    echo "  Container Subnet: $container_subnet"
    echo "  Primary Interface: $primary_iface"
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
    create_lme_nftables "$container_subnet" "$primary_iface" "$podman_iface" "$enable_wazuh_api"
    apply_nftables
    
    # Verify configuration
    verify_configuration
    
    # Provide troubleshooting info
    provide_troubleshooting
    
    log_success "LME nftables configuration completed!"
    log_info "Configuration will persist across reboots via /etc/nftables.conf"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
