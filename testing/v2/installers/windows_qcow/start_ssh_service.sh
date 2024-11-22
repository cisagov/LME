#!/bin/bash

VM_NAME="windows-runner"
MAX_ATTEMPTS=60  # 30 minutes total (30 sec intervals)
INTERVAL=30

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

# Monitor for successful configuration
echo "Monitoring for service configuration..."
attempt=1
service_configured=false
last_response_length=0
while [ $attempt -le $MAX_ATTEMPTS ]; do
    # Verify configuration
    /opt/minimega/bin/minimega -e 'cc exec powershell -Command "Get-Service sshd | Select-Object Name,Status,StartType"'
    
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
    
    # Check for service running and automatic
    if echo "$response" | grep -q "sshd.*Running.*Automatic"; then
        if ! $service_configured; then
            echo "SSH service is now running and set to automatic startup!"
        fi
        service_configured=true
        exit 0
    fi
    
    # If still running, wait and try again
    echo "Service not yet fully configured. Waiting $INTERVAL seconds..."
    sleep $INTERVAL
    attempt=$((attempt + 1))
done

echo "Timeout waiting for SSH service to be configured"
echo "Last response:"
/opt/minimega/bin/minimega -e "cc responses all"
exit 1
