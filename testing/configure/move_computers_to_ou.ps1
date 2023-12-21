# Import the Active Directory module
Import-Module ActiveDirectory

# Define the DN of the Computers container
$computersContainerDN = "CN=Computers,DC=lme,DC=local"

# Define the DN of the target OU
$targetOUDN = "OU=LMETestClients,DC=lme,DC=local"

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