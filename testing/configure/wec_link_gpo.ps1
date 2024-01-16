param(
    [string]$Domain = "lme.local",
    [string]$ClientOUCustomName = "LMEClients"
)

Import-Module ActiveDirectory

$DomainDN = $Domain -replace '\.', ',DC=' -replace '^', 'DC='
$ClientOUDistinguishedName = "OU=$ClientOUCustomName,$DomainDN"

$GPONameClient = "LME-WEC-Client"
$GPONameServer = "LME-WEC-Server"
$ServerOUDistinguishedName = "OU=Domain Controllers,$DomainDN"

try {
    New-GPLink -Name $GPONameClient -Target $ClientOUDistinguishedName
    Write-Output "GPO '$GPONameClient' linked to OU '$ClientOUCustomName'."
} catch {
    Write-Output "Error linking GPO '$GPONameClient' to OU '$ClientOUCustomName': $_"
}

try {
    New-GPLink -Name $GPONameServer -Target $ServerOUDistinguishedName
    Write-Output "GPO '$GPONameServer' linked to OU 'Domain Controllers'."
} catch {
    Write-Output "Error linking GPO '$GPONameServer' to OU 'Domain Controllers': $_"
}
