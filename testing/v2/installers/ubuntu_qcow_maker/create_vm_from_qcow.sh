#!/usr/bin/env bash

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -n, --name NAME       Set the VM name (default: ubuntu-runner)"
    echo "  -i, --image NAME      Set the image name (default: jammy-server-cloudimg-amd64.img)"
    echo "  -m, --memory SIZE     Set memory size in MB (default: 2048)"
    echo "  -c, --cpus NUMBER     Set number of CPUs (default: 2)"
    echo "  -t, --timeout TIME    Set QMP timeout in seconds (default: 30s)"
    echo "  -h, --help            Display this help message"
}

# Check if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
   echo "This script must be run as root" >&2
   exit 1
fi

# Set default values
VM_NAME="ubuntu-runner"
IMG_NAME="jammy-server-cloudimg-amd64.img"
MEMORY="2048"
CPUS="2"
QMP_TIMEOUT="30s"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            VM_NAME="$2"
            shift 2
            ;;
        -i|--image)
            IMG_NAME="$2"
            shift 2
            ;;
        -m|--memory)
            MEMORY="$2"
            shift 2
            ;;
        -c|--cpus)
            CPUS="$2"
            shift 2
            ;;
        -t|--timeout)
            QMP_TIMEOUT="$2"
            shift 2
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            print_usage
            exit 1
            ;;
    esac
done

# Export variables
export VM_NAME
export IMG_NAME
export MEMORY
export CPUS
export QMP_TIMEOUT

# Path for the SSH keys
SSH_KEY_PATH="$HOME/.ssh/id_rsa"
# Check if SSH key already exists
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "SSH key not found, generating a new one..."
    ssh-keygen -t rsa -b 2048 -f "$SSH_KEY_PATH" -N "" -C "ubuntu-vm"
fi

# Create the MM file with the VM configuration
MM_FILE_PATH="$(pwd)/$VM_NAME.mm"
cat > "$MM_FILE_PATH" <<EOF
clear vm config
shell sleep 10 
vm config memory $MEMORY
vm config vcpus $CPUS
vm config disk $(pwd)/$IMG_NAME
vm config snapshot true
vm config net 100
vm launch kvm $VM_NAME
vm start $VM_NAME
EOF

# Check if the MM file was created successfully
if [ ! -f "$MM_FILE_PATH" ]; then
    echo "Failed to create the MM file: $MM_FILE_PATH" >&2
    exit 1
fi

# Create, configure, and launch the VM using the MM file
/opt/minimega/bin/minimega -e "read $MM_FILE_PATH"

echo "VM $VM_NAME has been created and started."