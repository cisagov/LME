#!/bin/bash

# VM name
VM_NAME="ubuntu-builder"  # Replace with your actual VM name

# SSH user
SSH_USER="vmuser"  # Replace with the appropriate username

# Path to SSH key (if using key-based authentication)
SSH_KEY_PATH="$HOME/.ssh/id_rsa"  # Adjust this path as needed

# Maximum number of attempts to get IP and SSH
MAX_ATTEMPTS=30
SLEEP_INTERVAL=10

get_vm_ip() {
    #minimega -e .json true .filter name="$VM_NAME" vm info | jq -r '.[].Data[].Networks[].IP4'
    /opt/minimega/bin/minimega -e .json true vm info | jq -r ".[] | select(.Data[].Name == \"$VM_NAME\") | .Data[].Networks[].IP4"
}

wait_for_ssh() {
    local ip=$1
    for i in $(seq 1 $MAX_ATTEMPTS); do
        if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i "$SSH_KEY_PATH" "${SSH_USER}@${ip}" exit 2>/dev/null; then
            echo "SSH connection established."
            return 0
        fi
        echo "Attempt $i: Waiting for SSH to become available..."
        sleep $SLEEP_INTERVAL
    done
    echo "Timed out waiting for SSH connection."
    return 1
}

# Main loop
for attempt in $(seq 1 $MAX_ATTEMPTS); do
    echo "Attempt $attempt: Getting VM IP..."
    IP=$(get_vm_ip)
    echo $IP
    
    if [[ -n "$IP" && "$IP" != "null" ]]; then
        echo "Got IP: $IP. Waiting for SSH..."
        if wait_for_ssh "$IP"; then
            echo "Successfully connected to VM at $IP."
	    echo "Sleeping to wait for config to finish"
	    sleep 60
            ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" "${SSH_USER}@${IP}" "echo 'Builder VM is ready'"
            exit 0
        else
            echo "Failed to establish SSH connection."
            exit 1
        fi
    fi
    
    echo "No IP found. Waiting before next attempt..."
    sleep $SLEEP_INTERVAL
done

echo "Failed to get VM IP after $MAX_ATTEMPTS attempts."
exit 1
