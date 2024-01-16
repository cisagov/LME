# Define the directory path
param(
    [string]$DirectoryPath = "C:\lme"
)

# Create the directory if it doesn't already exist
if (-not (Test-Path -Path $DirectoryPath)) {
    New-Item -Path $DirectoryPath -ItemType Directory
}

# Define the security principal for 'All Users'
$allUsers = New-Object System.Security.Principal.SecurityIdentifier("S-1-1-0")

# Get the current ACL of the directory
$acl = Get-Acl -Path $DirectoryPath

# Define the rights (read and execute)
$rights = [System.Security.AccessControl.FileSystemRights]::ReadAndExecute

# Create the rule (allowing read and execute access)
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($allUsers, $rights, 'ContainerInherit, ObjectInherit', 'None', 'Allow')

# Add the rule to the ACL
$acl.AddAccessRule($accessRule)

# Set the ACL back to the directory
Set-Acl -Path $DirectoryPath -AclObject $acl
