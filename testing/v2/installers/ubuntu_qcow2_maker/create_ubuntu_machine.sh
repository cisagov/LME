#!/bin/bash

# Path for the SSH keys
SSH_KEY_PATH="$HOME/.ssh/id_rsa"

# Check if SSH key already exists
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "SSH key not found, generating a new one..."
    ssh-keygen -t rsa -b 2048 -f "$SSH_KEY_PATH" -N "" -C "ubuntu-vm"
fi

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
    username: vmuser
    password: $(echo 'vmuser' | openssl passwd -6 -stdin)
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

# Check if minimega is already running
if ! pgrep -x "minimega" > /dev/null; then
    # Start minimega in the background if not running
    minimega &
    # Give minimega a moment to start up
    sleep 2
fi

#vm config qemu-append -drive file=$(pwd)/$IMG_NAME,media=cdrom,index=0,readonly -drive file=$(pwd)/seed.img,media=cdrom,index=1,readonly
#vm config $VM_NAME meta user-data $(pwd)/user-data
# Create the MM file with the VM configuration
MM_FILE_PATH="$(pwd)/$VM_NAME.mm"
cat > "$MM_FILE_PATH" <<EOF
clear vm config
vm config memory $MEMORY
vm config vcpus $CPUS
vm config disk $(pwd)/$DISK_NAME
vm config qemu-append -drive file=$(pwd)/seed.img,media=cdrom,index0,readonly
vm config snapshot false
vm launch kvm $VM_NAME
EOF

# Check if the MM file was created successfully
if [ ! -f "$MM_FILE_PATH" ]; then
    echo "Failed to create the MM file: $MM_FILE_PATH"
    exit 1
fi

# Print the current directory
echo "Current directory: $(pwd)"

# Create, configure, and launch the VM using the MM file
minimega -e "read $MM_FILE_PATH"

# List the VMs to verify they are running
sleep 2
minimega -e "vm info"

