#!/bin/bash

set -e

# Check if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
   echo "This script must be run as root"
   exit 1
fi

# Set variables
export VM_NAME="ubuntu-builder"
#export VM_NAME="ubuntu-runner"
export IMG_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
export IMG_NAME="jammy-server-cloudimg-amd64.img"
export MEMORY="2048"        # Memory size in MB, adjust as needed
export CPUS="2"             # Number of CPUs, adjust as needed
export QMP_TIMEOUT="30s"     # QMP timeout in seconds, adjust as needed

# Path for the SSH keys
SSH_KEY_PATH="$HOME/.ssh/id_rsa"
# Check if SSH key already exists
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "SSH key not found, generating a new one..."
    ssh-keygen -t rsa -b 2048 -f "$SSH_KEY_PATH" -N "" -C "ubuntu-vm"
fi

# Download the image if it doesn't exist
if [ ! -f "$IMG_NAME" ]; then
    echo "Downloading image, this may take a while..."
    wget -q $IMG_URL -O $IMG_NAME
    echo "Image downloaded"
fi

# Install cloud-init package if not already installed
if ! command -v cloud-localds &> /dev/null; then
    echo "cloud-localds tool not found, installing cloud-image-utils..."
    sudo apt-get update
    sudo apt-get install -y cloud-image-utils
fi

# Create user-data file for cloud-init
cat > user-data <<EOF
#cloud-config
hostname: ubuntu-vm
manage_etc_hosts: true
users:
  - name: vmuser
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: users, admin
    home: /home/vmuser
    shell: /bin/bash
    lock_passwd: false
    ssh-authorized-keys:
      - $(cat ~/.ssh/id_rsa.pub)
ssh_pwauth: false
disable_root: false
chpasswd:
  list: |
    vmuser:vmuser
  expire: False
package_update: true
packages:
  - qemu-guest-agent
write_files:
  - path: /etc/resolv.conf
    content: |
      nameserver 8.8.8.8
runcmd:
  - [sed, -i, 's/#DNS=/DNS=8.8.8.8/g', /etc/systemd/resolved.conf]
  - [systemctl, restart, systemd-resolved]
final_message: "The system is finally up, after $UPTIME seconds"
EOF

# Create seed image for the autoinstall
cloud-localds seed.qcow2 user-data

# Check if minimega is already running
if ! pgrep -x "minimega" > /dev/null; then
    # Start minimega in the background if not running
    /opt/minimega/bin/minimega &
    # Give minimega a moment to start up
    sleep 2
fi

# Create the MM file with the VM configuration
MM_FILE_PATH="$(pwd)/$VM_NAME.mm"
cat > "$MM_FILE_PATH" <<EOF
namespace builder
clear vm config
tap create build ip 10.0.1.1/24
shell sleep 5
vm config memory $MEMORY
vm config vcpus $CPUS
vm config cdrom $(pwd)/seed.qcow2
vm config disk $(pwd)/$IMG_NAME
vm config snapshot false
vm config net build
dnsmasq start 10.0.1.1 10.0.1.2 10.0.1.254
vm config serial-ports 1
vm launch kvm $VM_NAME
vm start $VM_NAME
namespace
EOF


# Check if the MM file was created successfully
if [ ! -f "$MM_FILE_PATH" ]; then
    echo "Failed to create the MM file: $MM_FILE_PATH"
    exit 1
fi
# Create, configure, and launch the VM using the MM file
/opt/minimega/bin/minimega -e "read $MM_FILE_PATH"

# Wait until the machine is configured and then shut it down
./wait_for_login.sh

# Clear the mm config for the builder
/opt/minimega/bin/minimega -e "namespace builder vm kill $VM_NAME"

# Clear the mm config for the builder
/opt/minimega/bin/minimega -e "namespace builder vm flush"

/opt/minimega/bin/minimega -e "namespace"

sleep 10

# Clean up the machine specific setup
echo "Cleaning up artifacts from the image"
./clear_cloud_config.sh

