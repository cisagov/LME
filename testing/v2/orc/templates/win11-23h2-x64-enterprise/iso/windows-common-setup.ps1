# Don't stop if errors
$ErrorActionPreference = "Continue"
# Log all output to a file
if (-not (Test-Path "C:\ludus")) {
    New-Item -ItemType Directory -Path "C:\ludus"
}
Start-Transcript -path C:\ludus\setup-log.txt -append
# Start WinRM
Start-Service -Name 'WinRM' -ErrorAction Stop
# Install QEMU guest agent
if ([System.Environment]::Is64BitOperatingSystem) { 
    F:\guest-agent\qemu-ga-x86_64.msi /quiet
} 
else {
    F:\guest-agent\qemu-ga-x86.msi /quiet
}

# Disable IPV6
Get-NetAdapter | foreach { Disable-NetAdapterBinding -InterfaceAlias $_.Name -ComponentID ms_tcpip6 }
# Allow pings
netsh advfirewall firewall add rule name='ICMP Allow incoming V4 echo request' protocol=icmpv4:8,any dir=in action=allow
# Diable IPV6 over IPV4 tunneling
netsh interface teredo set state disabled
# Disable password expiration
wmic useraccount where "name='localuser'" set PasswordExpires=FALSE