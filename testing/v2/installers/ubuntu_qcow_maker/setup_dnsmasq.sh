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

# Set up dnsmasq for all VMs
/opt/minimega/bin/minimega -e "dnsmasq start $START_IP $RANGE_START $RANGE_END"

echo "dnsmasq has been set up for the IP range $RANGE_START to $RANGE_END"