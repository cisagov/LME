# Install OpenSSH Server
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
# Start and configure SSH service
Start-Service sshd
Set-Service -Name sshd -StartupType 'Automatic'
# Allow SSH through firewall
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22


# Ensure the user's home directory and .ssh folder exist
$userProfile = "C:\Users\$username"
$sshDir = "$userProfile\.ssh"
if (-not (Test-Path $sshDir)) {
    New-Item -Path $sshDir -ItemType Directory -Force
}

# Set appropriate permissions for the .ssh directory and files
icacls $sshDir /inheritance:r
icacls $sshDir /grant:r "$username:F"
icacls $sshDir /grant:r "SYSTEM:F"
icacls $authorizedKeysPath /inheritance:r
icacls $authorizedKeysPath /grant:r "$username:F"
icacls $authorizedKeysPath /grant:r "SYSTEM:F"

# Configure SSHD to allow public key authentication
$sshdConfigPath = "C:\ProgramData\ssh\sshd_config"
$sshdConfig = Get-Content $sshdConfigPath
$sshdConfig = $sshdConfig -replace "#PubkeyAuthentication yes", "PubkeyAuthentication yes"
$sshdConfig = $sshdConfig -replace "#PasswordAuthentication yes", "PasswordAuthentication no" # Optional: Disable password auth
Set-Content -Path $sshdConfigPath -Value $sshdConfig

# Restart SSHD to apply configuration changes
Restart-Service sshd
