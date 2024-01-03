# Ensure the .ssh directory exists
if (-not (Test-Path -Path $sshDirectory)) {
    New-Item -ItemType Directory -Path $sshDirectory
}

# Function to set ACL for the directory, granting FullControl to SYSTEM and applying inheritance
function Set-SystemOnlyAclForDirectory {
    param (
        [string]$path
    )

    $systemAccount = New-Object System.Security.Principal.NTAccount("NT AUTHORITY", "SYSTEM")
    $acl = Get-Acl -Path $path
    $acl.SetAccessRuleProtection($true, $false) # Enable ACL protection, disable inheritance
    $acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) | Out-Null } # Clear existing rules

    # Create and add the Access Rule for SYSTEM with inheritance
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($systemAccount, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.AddAccessRule($accessRule)

    # Apply the updated ACL to the directory
    Set-Acl -Path $path -AclObject $acl
}

# Function to set ACL for a file, granting FullControl only to SYSTEM
function Set-SystemOnlyAclForFile {
    param (
        [string]$path
    )

    $systemAccount = New-Object System.Security.Principal.NTAccount("NT AUTHORITY", "SYSTEM")
    $acl = Get-Acl -Path $path
    $acl.SetAccessRuleProtection($true, $false) # Enable ACL protection, disable inheritance
    $acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) | Out-Null } # Clear existing rules

    # Create and add the Access Rule for SYSTEM
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($systemAccount, "FullControl", "Allow")
    $acl.AddAccessRule($accessRule)

    # Apply the updated ACL to the file
    Set-Acl -Path $path -AclObject $acl
}

# Set ACL for the .ssh directory with inheritance
Set-SystemOnlyAclForDirectory -path $sshDirectory

# Ensure the known_hosts file exists
if (-not (Test-Path -Path $knownHostsFile)) {
    New-Item -ItemType File -Path $knownHostsFile
}

# Set ACL for the known_hosts file without inheritance
Set-SystemOnlyAclForFile -path $knownHostsFile

# Run ssh-keyscan and append output to known_hosts
ssh-keyscan $sshHost | Out-File -FilePath $knownHostsFile -Append -Encoding UTF8

# Output the contents of the known_hosts file
Get-Content -Path $knownHostsFile
