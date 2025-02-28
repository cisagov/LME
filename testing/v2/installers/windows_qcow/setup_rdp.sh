#!/bin/bash

VM_NAME="windows-runner"

# Check if cc is active
if ! ./check_cc_active.sh $VM_NAME; then
    echo "CC not active for $VM_NAME"
    exit 1
fi

# Set filter
echo "Setting filter..."
/opt/minimega/bin/minimega -e "cc filter name=$VM_NAME"
sleep 2

# Check current RDP status
echo "Checking current RDP status..."
/opt/minimega/bin/minimega -e 'cc exec query session'
sleep 2

# Enable RDP through registry with proper backslashes
echo "Enabling RDP in registry..."
/opt/minimega/bin/minimega -e 'cc exec reg add "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f'
/opt/minimega/bin/minimega -e 'cc exec reg add "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\Terminal Server" /v AllowRemoteRPC /t REG_DWORD /d 1 /f'
sleep 2

# Enable RDP services without -Force
echo "Enabling RDP services..."
/opt/minimega/bin/minimega -e 'cc exec powershell "Set-Service -Name \"TermService\" -StartupType Automatic"'
/opt/minimega/bin/minimega -e 'cc exec powershell "Start-Service -Name \"TermService\""'
sleep 2
/opt/minimega/bin/minimega -e 'cc exec powershell "Set-Service -Name \"UmRdpService\" -StartupType Automatic"'
/opt/minimega/bin/minimega -e 'cc exec powershell "Start-Service -Name \"UmRdpService\""'
sleep 2
/opt/minimega/bin/minimega -e 'cc exec powershell "Set-Service -Name \"SessionEnv\" -StartupType Automatic"'
/opt/minimega/bin/minimega -e 'cc exec powershell "Start-Service -Name \"SessionEnv\""'
sleep 5

# Create new firewall rules
echo "Configuring firewall..."
/opt/minimega/bin/minimega -e 'cc exec powershell "New-NetFirewallRule -DisplayName \"RDP-TCP\" -Direction Inbound -Protocol TCP -LocalPort 3389 -Action Allow -Profile Any"'
sleep 2
/opt/minimega/bin/minimega -e 'cc exec powershell "New-NetFirewallRule -DisplayName \"RDP-UDP\" -Direction Inbound -Protocol UDP -LocalPort 3389 -Action Allow -Profile Any"'
sleep 2

# Restart Terminal Services to apply changes
echo "Restarting Terminal Services..."
/opt/minimega/bin/minimega -e 'cc exec powershell "Restart-Service -Name \"TermService\" -Force"'
sleep 5

# Verify everything
echo "Checking RDP status..."
/opt/minimega/bin/minimega -e 'cc exec query session'
sleep 2

echo "Checking services..."
/opt/minimega/bin/minimega -e 'cc exec powershell "Get-Service TermService,UmRdpService,SessionEnv | Select-Object Name,Status,StartType"'
sleep 2

echo "Checking registry..."
/opt/minimega/bin/minimega -e 'cc exec reg query "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\Terminal Server" /v fDenyTSConnections'
sleep 2

echo "Checking firewall rules..."
/opt/minimega/bin/minimega -e 'cc exec powershell "Get-NetFirewallRule -DisplayName \"RDP*\" | Select-Object DisplayName,Enabled,Direction"'
sleep 2

echo "Checking network information..."
/opt/minimega/bin/minimega -e 'cc exec ipconfig'
sleep 2

echo "Checking listening ports..."
/opt/minimega/bin/minimega -e 'cc exec powershell "netstat -ano | findstr LISTENING"'
sleep 2

echo "Checking specifically for RDP port..."
/opt/minimega/bin/minimega -e 'cc exec powershell "netstat -ano | findstr 3389"'
sleep 60 

echo "Final configuration status:"
/opt/minimega/bin/minimega -e "cc responses all"

echo "RDP setup complete. Look for port 3389 in the listening ports above to confirm RDP is ready."
