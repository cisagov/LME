#!/bin/bash

VM_NAME="windows-runner"

if ! ./check_cc_active.sh $VM_NAME; then
    echo "CC not active for $VM_NAME"
    exit 1
fi

# Clear previous responses
echo "Clearing previous responses..."
/opt/minimega/bin/minimega -e "cc delete response all"

# Set filter
echo "Setting filter..."
/opt/minimega/bin/minimega -e "cc filter name=$VM_NAME"
sleep 2

# Check service status
echo "Checking SSH service status..."
/opt/minimega/bin/minimega -e 'cc exec powershell -Command "Get-Service sshd"'
sleep 2
echo "Service status response:"
/opt/minimega/bin/minimega -e "cc responses all"

# Clear responses
/opt/minimega/bin/minimega -e "cc delete response all"

# Configure service
echo "Configuring SSH service..."
/opt/minimega/bin/minimega -e 'cc exec powershell -Command "Set-Service -Name sshd -StartupType Automatic; Start-Service sshd"'
sleep 2
echo "Configuration response:"
/opt/minimega/bin/minimega -e "cc responses all"

# Clear responses
/opt/minimega/bin/minimega -e "cc delete response all"

# Verify configuration
echo "Verifying configuration..."
/opt/minimega/bin/minimega -e 'cc exec powershell -Command "Get-Service sshd | Select-Object Name,Status,StartType"'
sleep 2
echo "Final verification response:"
/opt/minimega/bin/minimega -e "cc responses all"
