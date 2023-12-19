# This script will ask the user for 2 things: the domain name, and the name of the OU for their 'hosts'
# After that information is collected it will link the GPO's created with the import_gpo script to the Domain Controllers OU and the custom host OU.

Import-Module ActiveDirectory

$domain = Read-Host "Enter your domain (e.g., 'lme.local')"
$domainDN = $domain -replace '\.', ',DC=' -replace '^', 'DC='

$customOUExists = Read-Host "Have you created a custom OU for your hosts? (yes/no)"
if ($customOUExists -ne "yes") {
    Write-Host "No custom OU specified. Exiting the script."
    exit
}

$ClientOUCustomName = Read-Host "Enter the name of your custom OU (e.g., MyComputers)"
$ClientOUDistinguishedName = "OU=$ClientOUCustomName,$domainDN"

$GPONameClient = "LME-WEC-Client"
$GPONameServer = "LME-WEC-Server"
$ServerOUDistinguishedName = "OU=Domain Controllers,$domainDN"

try {
    New-GPLink -Name $GPONameClient -Target $ClientOUDistinguishedName
    Write-Host "GPO '$GPONameClient' linked to OU '$ClientOUCustomName'."
} catch {
    Write-Host "Error linking GPO '$GPONameClient' to OU '$ClientOUCustomName': $_"
}

try {
    New-GPLink -Name $GPONameServer -Target $ServerOUDistinguishedName
    Write-Host "GPO '$GPONameServer' linked to OU 'Domain Controllers'."
} catch {
    Write-Host "Error linking GPO '$GPONameServer' to OU 'Domain Controllers': $_"
}
