#!/bin/env bash

# Set variables
export IMG_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
export IMG_NAME="jammy-server-cloudimg-amd64.img"
export VM_NAME="ubuntu-vm"
export MEMORY="2048"        # Memory size in MB, adjust as needed
export CPUS="2"             # Number of CPUs, adjust as needed
export DISK_NAME="ubuntu-vm.qcow2"
export DISK_SIZE="20G"      # Disk size, adjust as needed

# Download the image if it doesn't exist
if [ ! -f "$IMG_NAME" ]; then
    wget $IMG_URL -O $IMG_NAME
fi

# Create a virtual disk
qemu-img create -f qcow2 $DISK_NAME $DISK_SIZE

# Install cloud-init package if not already installed
if ! command -v cloud-localds &> /dev/null; then
    echo "cloud-localds tool not found, installing cloud-image-utils..."
    sudo apt-get update
    sudo apt-get install -y cloud-image-utils
fi

# Create user-data file for cloud-init
cat > user-data <<EOF
#cloud-config
autoinstall:
  version: 1
  identity:
    hostname: ubuntu-vm
    username: lme-user
    password: $(echo 'lme-user' | openssl passwd -6 -stdin)
  ssh:
    install-server: true
    authorized-keys:
      - $(cat ~/.ssh/id_rsa.pub)
  storage:
    layout:
      name: direct
EOF

# Create seed image for the autoinstall
cloud-localds seed.img user-data

# Start minimega and create the VM
minimega -p 9000 << EOF
vm config memory $MEMORY
vm config cpus $CPUS
vm config disk $DISK_NAME,format=qcow2
vm config disk $IMG_NAME,readonly
vm config disk seed.img,readonly
vm config name $VM_NAME
vm launch $VM_NAME
EOF