#!/bin/bash

# Initialize variables
VM_NAME=""
VM_USER=""
MAX_ATTEMPTS=30
SLEEP_INTERVAL=10

# Function to print usage
usage() {
    echo "Usage: $0 -n <vm_name> -u <vm_user>"
    echo "  -n    Specify the VM name"
    echo "  -u    Specify the VM user"
    exit 1
}

# Parse command-line arguments
while getopts "n:u:" opt; do
    case $opt in
        n) VM_NAME="$OPTARG" ;;
        u) VM_USER="$OPTARG" ;;
        *) usage ;;
    esac
done

# Check if required arguments are provided
if [[ -z "$VM_NAME" || -z "$VM_USER" ]]; then
    echo "Error: Both VM name and VM user must be provided."
    usage
fi

get_ip() {
    /opt/minimega/bin/minimega -e .json true .filter name="$VM_NAME" vm info | jq -r '.[].Data[].Networks[].IP4'
}

echo "Waiting for IP assignment for VM: $VM_NAME (User: $VM_USER)"

IP=""
for ((i=1; i<=MAX_ATTEMPTS; i++)); do
    IP=$(get_ip)

    if [[ -z "$IP" || "$IP" == "null" ]]; then
        echo "Attempt $i: No IP assigned yet. Waiting $SLEEP_INTERVAL seconds..."

        if [[ $i -eq $MAX_ATTEMPTS ]]; then
            echo "Timeout: Failed to get IP for $VM_NAME after $MAX_ATTEMPTS attempts."
            exit 1
        fi

        sleep $SLEEP_INTERVAL
    else
        echo "The IP of $VM_NAME is $IP"
        break
    fi
done

echo "VM Name: $VM_NAME"
echo "VM User: $VM_USER"
echo "VM IP: $IP"

ssh  -o StrictHostKeyChecking=no $VM_USER@$IP 'sudo apt-get update && sudo apt-get -y install ansible'

echo "Ansible installed successfully on $VM_NAME"

ssh  -o StrictHostKeyChecking=no $VM_USER@$IP 'cd ~ && git clone https://github.com/cisagov/LME.git'

# Run the ansible installer here once it is merged to LME


