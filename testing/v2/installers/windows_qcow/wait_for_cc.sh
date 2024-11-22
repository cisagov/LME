#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Usage: $0 <vm-name> [-t timeout-in-seconds]"
    exit 1
fi

VM_NAME="$1"
shift

# Parse optional timeout argument
TIMEOUT=600  # Default timeout of 10 minutes (600 seconds)
while getopts "t:" opt; do
    case $opt in
        t) TIMEOUT="$OPTARG" ;;
        \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
    esac
done

INTERVAL=30  # Check every 30 seconds

echo "Waiting for CC to become active on $VM_NAME (timeout: ${TIMEOUT}s)"
start_time=$(date +%s)

while [ $(($(date +%s) - start_time)) -lt $TIMEOUT ]; do
    # Use jq to find ActiveCC status for the specific VM
    CC_STATUS=$(/opt/minimega/bin/minimega -e ".json true vm info" | \
        jq -r --arg name "$VM_NAME" '.[].Data[] | select(.Name == $name) | .ActiveCC')
    
    if [ "$CC_STATUS" = "true" ]; then
        elapsed=$(($(date +%s) - start_time))
        echo "CC became active after ${elapsed} seconds"
        exit 0
    fi
    echo "CC not yet active, waiting ${INTERVAL} seconds... ($(((TIMEOUT - ($(date +%s) - start_time)))) seconds remaining)"
    sleep $INTERVAL
done

echo "Timeout waiting for CC to become active on $VM_NAME after ${TIMEOUT} seconds"
exit 1
