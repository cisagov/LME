param(
    [string]$Domain = "lme.local",
    [string]$ClientOUCustomName = "LMETestClients"
)

Import-Module ActiveDirectory

$domainDN = $Domain -replace '\.', ',DC=' -replace '^', 'DC='
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
