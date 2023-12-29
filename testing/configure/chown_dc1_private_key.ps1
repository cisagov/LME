# Path to the private key
$privateKeyPath = "C:\lme\id_rsa"

# Define the SYSTEM account
$systemAccount = New-Object System.Security.Principal.NTAccount("NT AUTHORITY", "SYSTEM")

# Get the current ACL of the file
$acl = Get-Acl -Path $privateKeyPath

# Clear any existing Access Rules (optional - do this if you want to restrict access to SYSTEM only)
$acl.SetAccessRuleProtection($true, $false)
$acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) | Out-Null }

# Create a new Access Rule granting FullControl to SYSTEM
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($systemAccount, "FullControl", "Allow")

# Add the Access Rule to the ACL
$acl.AddAccessRule($accessRule)

# Set the updated ACL back to the file
Set-Acl -Path $privateKeyPath -AclObject $acl
