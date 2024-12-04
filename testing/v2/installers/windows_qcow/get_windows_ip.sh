#!/bin/bash

# Check if VM name argument is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <vm-name>"
    exit 1
fi

VM_NAME="$1"

# Use jq to find ip for a specific VM
/opt/minimega/bin/minimega -e ".json true vm info" | jq -r --arg name "$VM_NAME" '.[].Data[] | select(.Name == $name) .Networks[0].IP4'