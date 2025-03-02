#!/bin/bash

VM_NAME="windows-runner"
MAX_ATTEMPTS=60  # 30 minutes total (30 sec intervals)
INTERVAL=30

# Check if cc is active
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

# Check initial state
echo "Checking current OpenSSH state..."
/opt/minimega/bin/minimega -e 'cc exec powershell -Command "Get-WindowsCapability -Online | Where-Object Name -like \"OpenSSH*\""'
sleep 2
echo "Initial state response:"
/opt/minimega/bin/minimega -e "cc responses all"

# Start OpenSSH installation
echo "Starting DISM installation..."
/opt/minimega/bin/minimega -e 'cc exec powershell -Command "DISM.exe /Online /Add-Capability /CapabilityName:OpenSSH.Server~~~~0.0.1.0"'

# Function to check OpenSSH final status
check_openssh_status() {
    # Get all responses including OpenSSH status
    /opt/minimega/bin/minimega -e 'cc exec powershell -Command "Get-WindowsCapability -Online | Where-Object Name -like \"OpenSSH*\""'
    local response=$(/opt/minimega/bin/minimega -e "cc responses all")

    # Check if we see both client and server lines
    if echo "$response" | grep -q "OpenSSH.Server" && \
       echo "$response" | grep -q "OpenSSH.Client"; then
        echo "Found OpenSSH Server and Client status"
        exit 0
    fi
    return 1
}

# Monitor installation progress
attempt=1
dism_completed=false
last_response_length=0
while [ $attempt -le $MAX_ATTEMPTS ]; do
    echo "Checking installation status (Attempt $attempt/$MAX_ATTEMPTS)..."
    
    # Get all responses
    response=$(/opt/minimega/bin/minimega -e "cc responses all")
    current_response_length=${#response}
    
    # Only print new content if response has changed
    if [ $current_response_length -gt $last_response_length ]; then
        echo "New output received:"
        echo "$response" | tail -n $(($(echo "$response" | wc -l) - $(echo "$last_response" | wc -l)))
        last_response_length=$current_response_length
        last_response="$response"
    fi
    
    # Check for DISM completion
    if echo "$response" | grep -q "The operation completed successfully"; then
        if ! $dism_completed; then
            echo "DISM operation completed successfully"
        fi
        dism_completed=true
        
        # Now that DISM is complete, check OpenSSH status
        if check_openssh_status; then
            echo "OpenSSH Server and Client are both installed successfully!"
            exit 0
        fi
    fi
    
    # If still running, wait and try again
    echo "Installation still in progress. Waiting $INTERVAL seconds..."
    sleep $INTERVAL
    attempt=$((attempt + 1))
done

echo "Timeout waiting for OpenSSH installation to complete"
echo "Last response:"
/opt/minimega/bin/minimega -e "cc responses all"
exit 1
