#!/bin/bash

# Default values
DEFAULT_IMAGE_PATH="/home/lme-user/ubuntu_qcow_maker/jammy-server-cloudimg-amd64.img"
DEFAULT_SIZE="100G"

# Function to display usage
usage() {
    echo "Usage: $0 [-i IMAGE_PATH] [-s SIZE]"
    echo "  -i IMAGE_PATH : Path to the QCOW2 disk image (default: $DEFAULT_IMAGE_PATH)"
    echo "  -s SIZE       : Desired size (default: $DEFAULT_SIZE)"
    exit 1
}

# Function to convert size to bytes
to_bytes() {
    local size=$1
    local unit=${size: -1}
    local number=${size%?}
    case $unit in
        G|g) echo $((number * 1024 * 1024 * 1024)) ;;
        M|m) echo $((number * 1024 * 1024)) ;;
        K|k) echo $((number * 1024)) ;;
        *) echo $number ;;
    esac
}

# Parse command-line options
while getopts ":i:s:h" opt; do
    case ${opt} in
        i ) IMAGE_PATH=$OPTARG ;;
        s ) DESIRED_SIZE=$OPTARG ;;
        h ) usage ;;
        \? ) echo "Invalid option: $OPTARG" 1>&2; usage ;;
        : ) echo "Invalid option: $OPTARG requires an argument" 1>&2; usage ;;
    esac
done

# Set variables to default values if not provided
IMAGE_PATH=${IMAGE_PATH:-$DEFAULT_IMAGE_PATH}
DESIRED_SIZE=${DESIRED_SIZE:-$DEFAULT_SIZE}

# Check if the image file exists
if [ ! -f "$IMAGE_PATH" ]; then
    echo "Error: Image file $IMAGE_PATH does not exist."
    exit 1
fi

# Get the current size of the image in bytes
CURRENT_SIZE=$(qemu-img info "$IMAGE_PATH" --output=json | jq -r '.["virtual-size"]')
DESIRED_SIZE_BYTES=$(to_bytes $DESIRED_SIZE)

if [ $CURRENT_SIZE -eq $DESIRED_SIZE_BYTES ]; then
    echo "Disk image is already $DESIRED_SIZE. No resize needed."
elif [ $CURRENT_SIZE -gt $DESIRED_SIZE_BYTES ]; then
    echo "Error: Current size ($CURRENT_SIZE bytes) is larger than desired size ($DESIRED_SIZE_BYTES bytes). Shrinking the image is not supported."
    exit 1
else
    echo "Resizing disk image to $DESIRED_SIZE"
    qemu-img resize "$IMAGE_PATH" "$DESIRED_SIZE"
    if [ $? -eq 0 ]; then
        echo "Disk image successfully resized to $DESIRED_SIZE"
    else
        echo "Error: Failed to resize disk image"
        exit 1
    fi
fi

echo "Current disk image size:"
qemu-img info "$IMAGE_PATH" | grep 'virtual size'