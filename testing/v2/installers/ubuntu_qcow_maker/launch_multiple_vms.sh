#!/bin/bash

# Check if an argument is provided, otherwise use default value of 1
NUM_VMS=${1:-1}

# Validate that NUM_VMS is a positive integer
if ! [[ "$NUM_VMS" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: Please provide a positive integer for the number of VMs."
    echo "Usage: $0 [number_of_vms]"
    exit 1
fi

echo "Creating $NUM_VMS VM(s)..."

for i in $(seq 1 $NUM_VMS)
do
    VM_NAME="ubuntu-runner-$i"
    echo "Creating VM: $VM_NAME"
    sudo ./create_vm_from_qcow.sh -n $VM_NAME
    sleep 10  # Wait a bit between VM creations
done

echo "All $NUM_VMS VM(s) created. Use 'minimega vm info' to see their status and IP addresses."