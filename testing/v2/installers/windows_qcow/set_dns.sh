#!/bin/bash

VM_NAME="windows-runner"

# Check if cc is active
if ! ./check_cc_active.sh $VM_NAME; then
    echo "CC not active for $VM_NAME"
    exit 1
fi

# Set filter for our VM
/opt/minimega/bin/minimega -e "cc filter name=$VM_NAME"

echo "Setting DNS to 1.1.1.1 and 8.8.8.8..."
/opt/minimega/bin/minimega -e 'cc exec powershell -Command "Set-DnsClientServerAddress -InterfaceAlias Ethernet -ServerAddresses (\"1.1.1.1\",\"8.8.8.8\")"'
sleep 3
/opt/minimega/bin/minimega -e "cc responses all"

echo "Verifying DNS settings..."
/opt/minimega/bin/minimega -e 'cc exec powershell -Command "Get-DnsClientServerAddress -InterfaceAlias Ethernet"'
sleep 3
/opt/minimega/bin/minimega -e "cc responses all"

echo "Testing DNS resolution..."
/opt/minimega/bin/minimega -e 'cc exec ping github.com -n 1'
sleep 3
/opt/minimega/bin/minimega -e "cc responses all"
