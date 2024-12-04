#!/bin/bash
run_elevated_powershell() {
    local command="$1"
    local host_arg="$2"
    
    # Use passed host, environment variable, or default value
    HOST=${host_arg:-${WINDOWS_HOST:-"10.0.0.180"}}
    USER="Test"
    
    # Add host key if not already present
    ssh-keyscan -H $HOST >> ~/.ssh/known_hosts 2>/dev/null
    
    # Run the command
    sshpass -e ssh $USER@$HOST "powershell -NoProfile -Command \"& {Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command \\\"${command}\\\"' -Verb RunAs -Wait}\""
}

# Example usage:
# run this first before running the below commands
# export SSHPASS='windowspassword'

# Using default:
# run_elevated_powershell "Get-Service sshd"

# Passing host as argument:
# run_elevated_powershell "Get-Service sshd" "10.0.0.180"

# Using environment variable:
# export WINDOWS_HOST="10.0.0.180"
# run_elevated_powershell "Get-Service sshd"