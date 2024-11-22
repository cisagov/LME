#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root"
    exit 1
fi

# Default values
WAN=${1:-eth0}
INTERNAL=${2:-mega_tap0}

echo "Using WAN interface: $WAN"
echo "Using INTERNAL interface: $INTERNAL"

# Function to check if a specific rule exists in a chain
check_rule() {
    local table=$1
    local chain=$2
    local rule_spec=$3
    iptables -t "$table" -C "$chain" $rule_spec 2>/dev/null
    return $?
}

# Function to check if all required rules are present
check_all_rules() {
    # Check NAT rule in POSTROUTING chain
    check_rule nat POSTROUTING "-o $WAN -j MASQUERADE" || return 1
    
    # Check forwarding rules in FORWARD chain
    check_rule filter FORWARD "-i $INTERNAL -o $WAN -j ACCEPT" || return 1
    check_rule filter FORWARD "-i $WAN -o $INTERNAL -m state --state RELATED,ESTABLISHED -j ACCEPT" || return 1
    
    return 0
}

# Function to check VM connectivity
check_vm_connectivity() {
    local VM_IP=$(ip addr show $INTERNAL | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

    if [ -z "$VM_IP" ]; then
        echo "Could not determine VM IP address. Please check manually."
        return 1
    fi

    echo "Checking internet connectivity from VM ($VM_IP)..."
    if ! ping -c 3 -I $VM_IP 8.8.8.8 > /dev/null 2>&1; then
        echo "Internet connectivity test failed. Please check your configuration."
        return 1
    fi
    echo "Internet connectivity test successful."

    echo "Testing DNS resolution..."
    if ! nslookup -timeout=5 google.com > /dev/null 2>&1; then
        echo "DNS resolution test failed. Please check your DNS configuration."
        return 1
    fi
    echo "DNS resolution test successful."
    
    return 0
}

# Check if IP forwarding is enabled
ip_forward=$(cat /proc/sys/net/ipv4/ip_forward)
if [ "$ip_forward" != "1" ]; then
    echo "Enabling IP forwarding..."
    sysctl -w net.ipv4.ip_forward=1
fi

# Check if rules already exist
if check_all_rules; then
    echo "Firewall rules already exist. No changes needed."
    check_vm_connectivity
    exit $?
fi

echo "Setting up new firewall rules..."

# Flush existing rules
iptables -F
iptables -t nat -F

# Set up NAT
iptables -t nat -A POSTROUTING -o $WAN -j MASQUERADE

# Allow all forwarding from internal network to WAN (both TCP and UDP)
iptables -A FORWARD -i $INTERNAL -o $WAN -j ACCEPT

# Allow established and related incoming connections
iptables -A FORWARD -i $WAN -o $INTERNAL -m state --state RELATED,ESTABLISHED -j ACCEPT

echo "New firewall rules have been set up."

# Check connectivity after setting up new rules
check_vm_connectivity
exit $?