#!/usr/bin/env bash

# Default values
TAP_NAME="100"  # Match the vm config net value
IP_ADDRESS="10.0.0.1/24"
FORCE=false
MAX_WAIT=10  # Maximum seconds to wait for interface

# Extract just the IP without the subnet mask for comparison
IP_ONLY="${IP_ADDRESS%/*}"

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -t, --tap     TAP/VLAN name (default: 100)"
    echo "  -i, --ip      IP address (default: 10.0.0.1/24)"
    echo "  -f, --force   Force recreation of TAP interface"
    echo "  -h, --help    Show this help message"
    echo
    echo "Example:"
    echo "  $0 -t 200 -i 192.168.1.1/24"
    exit 1
}

# Function to check if VLAN already exists
check_vlan_exists() {
    local vlan="$1"
    if sudo /opt/minimega/bin/minimega -e "tap" | grep -q "| $vlan$"; then
        return 0  # VLAN exists
    fi
    return 1     # VLAN doesn't exist
}

# Function to wait for interface to be ready
wait_for_interface() {
    local count=0
    while [ $count -lt $MAX_WAIT ]; do
        if ip addr show | grep -A 2 "mega_tap" | grep -q "inet $IP_ADDRESS\\|inet $IP_ONLY/"; then
            return 0
        fi
        sleep 1
        count=$((count + 1))
        echo "Still waiting... ($count/$MAX_WAIT)"
    done
    return 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--tap)
            TAP_NAME="$2"
            shift 2
            ;;
        -i|--ip)
            IP_ADDRESS="$2"
            IP_ONLY="${IP_ADDRESS%/*}"
            shift 2
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -h|--help)
            show_usage
            ;;
        *)
            echo "Unknown argument: $1"
            show_usage
            ;;
    esac
done

# Check if VLAN already exists
if check_vlan_exists "$TAP_NAME"; then
    if [ "$FORCE" = true ]; then
        echo "VLAN $TAP_NAME already exists, but -f was specified. Cleaning up..."
        sudo /opt/minimega/bin/minimega -e "clear tap"
        sleep 1
    else
        echo "VLAN $TAP_NAME already exists. Current configuration:"
        sudo /opt/minimega/bin/minimega -e "tap"
        echo -e "\nUse -f to force recreation if needed."
        exit 0
    fi
fi

# Create the TAP interface
echo "Creating TAP interface for vm config net ${TAP_NAME} with IP ${IP_ADDRESS}..."
sudo /opt/minimega/bin/minimega -e "tap create ${TAP_NAME} ip ${IP_ADDRESS}"

# Verify creation with timeout
echo "Waiting for interface to be ready..."
if wait_for_interface; then
    echo "TAP interface created successfully!"
    echo -e "\nInterface details:"
    ip addr show | grep -A 2 "mega_tap"
    echo -e "\nThis interface will work with: vm config net ${TAP_NAME}"

    # Show minimega tap status
    echo -e "\nMinimega TAP status:"
    sudo /opt/minimega/bin/minimega -e "tap"
    exit 0
else
    echo "Note: Interface appears to exist but IP verification failed."
    echo "Current interfaces:"
    ip addr show | grep -A 2 "mega_tap"

    # Show minimega tap status
    echo -e "\nMinimega TAP status:"
    sudo /opt/minimega/bin/minimega -e "tap"

    # If interface exists but verification failed, still exit successfully
    if ip addr show | grep -q "mega_tap"; then
        echo "Interface exists and should work with: vm config net ${TAP_NAME}"
        exit 0
    fi
    exit 1
fi
