#!/bin/bash

VM_NAME="windows-runner"

# Check if cc is active
if ! ./check_cc_active.sh $VM_NAME; then
    echo "CC not active for $VM_NAME"
    exit 1
fi

# Set filter for our VM
/opt/minimega/bin/minimega -e "cc filter name=$VM_NAME"

# Verify connection
/opt/minimega/bin/minimega -e "cc clients"

# Run commands and check responses
/opt/minimega/bin/minimega -e 'cc exec where winget'
/opt/minimega/bin/minimega -e "cc responses all"

/opt/minimega/bin/minimega -e 'cc exec systeminfo'
/opt/minimega/bin/minimega -e "cc responses all"
