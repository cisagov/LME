#!/usr/bin/env bash

# Default values
TAP_NAME="100"
IP_ADDRESS="10.0.0.1/24"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--tap)
            TAP_NAME="$2"
            shift 2
            ;;
        -i|--ip)
            IP_ADDRESS="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

# Execute the minimega command with the provided or default arguments
sudo /opt/minimega/bin/minimega -e tap create "$TAP_NAME" ip "$IP_ADDRESS"
