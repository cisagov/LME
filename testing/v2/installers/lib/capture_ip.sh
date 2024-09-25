#!/bin/bash

# Capture the IP address of eth0
IP0=$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

# Check if the IP was successfully captured
if [ -n "$IP0" ]; then
    echo $IP0
    export IP0
else
    echo "Failed to capture eth0 IP address"
    exit 1
fi
