#!/bin/bash

# Default values
WAN=${1:-eth0}
INTERNAL=${2:-mega_tap0}

echo "Using WAN interface: $WAN"
echo "Using INTERNAL interface: $INTERNAL"

# Enable IP forwarding
sysctl -w net.ipv4.ip_forward=1

# Flush existing rules
iptables -F
iptables -t nat -F

# Set up NAT
iptables -t nat -A POSTROUTING -o $WAN -j MASQUERADE

# Allow all forwarding from internal network to WAN (both TCP and UDP)
iptables -A FORWARD -i $INTERNAL -o $WAN -j ACCEPT

# Allow established and related incoming connections
iptables -A FORWARD -i $WAN -o $INTERNAL -m state --state RELATED,ESTABLISHED -j ACCEPT

echo "Firewall rules have been updated."

# Check VM internet connectivity
VM_IP=$(ip addr show $INTERNAL | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

if [ -z "$VM_IP" ]; then
    echo "Could not determine VM IP address. Please check manually."
else
    echo "Checking internet connectivity from VM ($VM_IP)..."
    if ping -c 3 -I $VM_IP 8.8.8.8 > /dev/null 2>&1; then
        echo "Internet connectivity test successful."
    else
        echo "Internet connectivity test failed. Please check your configuration."
    fi

    echo "Testing DNS resolution..."
    if nslookup -timeout=5 google.com > /dev/null 2>&1; then
        echo "DNS resolution test successful."
    else
        echo "DNS resolution test failed. Please check your DNS configuration."
    fi
fi