param(
    [string]$Domain = "lme.local",
    [string]$ClientOUCustomName = "LMEClients"
)

Import-Module ActiveDirectory

$domainDN = $Domain -replace '\.', ',DC=' -replace '^', 'DC='
$OUDistinguishedName = "OU=$ClientOUCustomName,$domainDN"

$GPOName = "LME-Sysmon-Task"

try {
    New-GPLink -Name $GPOName -Target $OUDistinguishedName
    Write-Host "GPO '$GPOName' linked to OU '$ClientOUCustomName'."
} catch {
    Write-Host "Error linking GPO '$GPOName' to OU '$ClientOUCustomName': $_"
}
