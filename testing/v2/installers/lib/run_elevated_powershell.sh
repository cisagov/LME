#!/bin/bash
#set -ex

# Check if command argument is provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <command> [host]"
    echo "Example: $0 'Get-Service sshd' 10.0.0.180"
    echo "Note: Set SSHPASS and/or WINDOWS_HOST environment variables if needed"
    exit 1
fi

command="$1"
host_arg="$2"

# Check if SSHPASS is set
if [ -z "$SSHPASS" ]; then
    echo "Error: SSHPASS environment variable must be set"
    echo "Example: export SSHPASS='windowspassword'"
    exit 1
fi

# Use passed host, environment variable, or default value
HOST=${host_arg:-${WINDOWS_HOST:-"10.0.0.180"}}
USER="Test"

# Add host key if not already present
ssh-keyscan -H $HOST >> ~/.ssh/known_hosts 2>/dev/null

# Run the command
sshpass -e ssh $USER@$HOST "powershell -NoProfile -Command \"Start-Process PowerShell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', '${command} *>&1 > C:\\Users\\Test\\service.txt' -Verb RunAs -Wait -PassThru; Get-Content C:\\Users\\Test\\service.txt\""