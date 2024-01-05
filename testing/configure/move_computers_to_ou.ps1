param(
    [string]$Domain = "lme.local",
    [string]$ClientOUCustomName = "LMEClients",
    [string]$CurrentCN = "Computers"
)

# Import the Active Directory module
Import-Module ActiveDirectory

# Split the domain into its parts
$domainParts = $Domain -split '\.'

# Construct the domain DN, starting with 'DC='
$domainDN = 'DC=' + ($domainParts -join ',DC=')

# Define the DN of the existing Computers container
$computersContainerDN = "CN=$CurrentCN,$domainDN"

# Define the DN of the target OU
$targetOUDN = "OU=$ClientOUCustomName,$domainDN"

# Output the DNs for verification
Write-Host "Current Computers Container DN: $computersContainerDN"
Write-Host "Target OU DN: $targetOUDN"

# Get the computer accounts in the Computers container
$computers = Get-ADComputer -Filter * -SearchBase $computersContainerDN

# Move each computer to the target OU
foreach ($computer in $computers) {
    try {
        # Move the computer to the target OU
        Move-ADObject -Identity $computer.DistinguishedName -TargetPath $targetOUDN
        Write-Host "Moved $($computer.Name) to $targetOUDN"
    } catch {
        Write-Host "Failed to move $($computer.Name): $_"
    }
}