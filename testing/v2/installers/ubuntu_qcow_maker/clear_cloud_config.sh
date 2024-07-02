#!/bin/bash
set -e

# Default values
MOUNT_PATH="/mnt/disk_image"
DISK_IMAGE="/home/lme-user/ubuntu_qcow_maker/jammy-server-cloudimg-amd64.img"

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -m, --mount-path PATH    Specify the mount path (default: $MOUNT_PATH)"
    echo "  -i, --image PATH         Specify the path to the disk image (default: $DISK_IMAGE)"
    echo "  -h, --help               Show this help message"
}

# Parse command-line options
while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--mount-path)
            MOUNT_PATH="$2"
            shift 2
            ;;
        -i|--image)
            DISK_IMAGE="$2"
            shift 2
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

echo "Using mount path: $MOUNT_PATH"
echo "Using disk image: $DISK_IMAGE"

sudo mkdir -p $MOUNT_PATH

# Mount the image
sudo guestmount -a "$DISK_IMAGE" -m /dev/sda1 $MOUNT_PATH

# Remove cloud-init artifacts
sudo rm -rf $MOUNT_PATH/var/lib/cloud/*

# Remove the file that indicates cloud-init has already run
sudo rm -f $MOUNT_PATH/etc/cloud/cloud-init.disabled

# Set up a default name server
sudo sed -i 's/#DNS=/DNS=8.8.8.8/g' $MOUNT_PATH/etc/systemd/resolved.conf

# Truncate the machine-id file
sudo truncate -s 0 $MOUNT_PATH/etc/machine-id

# Remove the file that stores the instance ID
sudo rm -f $MOUNT_PATH/var/lib/dbus/machine-id

# Modify the netplan configuration created by cloud-init
NETPLAN_FILE=$MOUNT_PATH/etc/netplan/50-cloud-init.yaml
NEW_CONTENT=$(cat << EOF
network:
    ethernets:
        ens1:
            dhcp4: true
            dhcp6: true
    version: 2
EOF
)
echo "$NEW_CONTENT" | sudo tee "$NETPLAN_FILE" > /dev/null

# Unmount the image
sudo umount $MOUNT_PATH
