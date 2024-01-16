# Path to the private key
$PrivateKeyPath = "C:\lme\id_rsa"

# Define the SYSTEM account
$SystemAccount = New-Object System.Security.Principal.NTAccount("NT AUTHORITY", "SYSTEM")

# Get the current ACL of the file
$Acl = Get-Acl -Path $PrivateKeyPath

# Clear any existing Access Rules
$Acl.SetAccessRuleProtection($true, $false)
$Acl.Access | ForEach-Object { $Acl.RemoveAccessRule($_) | Out-Null }

# Create a new Access Rule granting FullControl to SYSTEM
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($SystemAccount, "FullControl", "Allow")

# Add the Access Rule to the ACL
$Acl.AddAccessRule($accessRule)

# Set the updated ACL back to the file
Set-Acl -Path $PrivateKeyPath -AclObject $Acl
