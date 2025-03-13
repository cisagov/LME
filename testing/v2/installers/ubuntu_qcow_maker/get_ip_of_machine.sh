#!/bin/bash

VM_NAME="$1"
MAX_ATTEMPTS=30
SLEEP_INTERVAL=10

get_ip() {
    /opt/minimega/bin/minimega -e ".json true vm info" | jq -r --arg name "$VM_NAME" '.[].Data[] | select(.Name == $name) .Networks[0].IP4'
}

echo "Waiting for IP assignment for VM: $VM_NAME"

for ((i=1; i<=MAX_ATTEMPTS; i++)); do
    IP=$(get_ip)

    if [[ -n "$IP" && "$IP" != "null" ]]; then
        echo "The IP of $VM_NAME is $IP"
        exit 0
    fi

    echo "Attempt $i: No IP assigned yet. Waiting $SLEEP_INTERVAL seconds..."
    sleep $SLEEP_INTERVAL
done

echo "Timeout: Failed to get IP for $VM_NAME after $MAX_ATTEMPTS attempts."
