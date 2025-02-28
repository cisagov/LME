#!/bin/bash

# Default values
START_IP="10.0.0.1"
RANGE_START="10.0.0.2"
RANGE_END="10.0.0.254"

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -s, --start-ip IP      Set the start IP (default: $START_IP)"
    echo "  -r, --range-start IP   Set the range start IP (default: $RANGE_START)"
    echo "  -e, --range-end IP     Set the range end IP (default: $RANGE_END)"
    echo "  -h, --help             Display this help message"
}

# Function to check if dnsmasq is already running with our configuration
check_dnsmasq_running() {
    # Look for dnsmasq process with our specific configuration
    # Using ps and grep, excluding the grep process itself
    if ps ax | grep -v grep | grep dnsmasq | grep -q "listen-address $START_IP.*dhcp-range $RANGE_START,$RANGE_END"; then
        echo "Found dnsmasq running with the correct configuration"
        return 0  # dnsmasq is running with our configuration
    fi
    return 1  # dnsmasq is not running or not configured as we need
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--start-ip)
            START_IP="$2"
            shift 2
            ;;
        -r|--range-start)
            RANGE_START="$2"
            shift 2
            ;;
        -e|--range-end)
            RANGE_END="$2"
            shift 2
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Check if dnsmasq is already running with our configuration
if check_dnsmasq_running; then
    echo "dnsmasq is already running with the correct IP range ($RANGE_START to $RANGE_END)"
    exit 0
fi

# If we get here, either dnsmasq isn't running or it's running with wrong configuration
# We'll let minimega handle stopping any existing instance and starting a new one

# Set up dnsmasq for all VMs
echo "Starting dnsmasq with IP range $RANGE_START to $RANGE_END..."
/opt/minimega/bin/minimega -e "dnsmasq start $START_IP $RANGE_START $RANGE_END"

# Wait a moment for dnsmasq to start
sleep 2

# Verify the setup was successful
if check_dnsmasq_running; then
    echo "dnsmasq has been successfully set up for the IP range $RANGE_START to $RANGE_END"
    exit 0
else
    echo "Failed to start dnsmasq. Please check the logs for errors."
    exit 1
fi