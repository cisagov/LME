param(
    [string]$Domain = "lme.local",
    [string]$ClientOUCustomName = "LMEClients"
)

Import-Module ActiveDirectory

# Split the domain into parts and construct the ParentContainerDN
$DomainParts = $Domain -split "\."
$ParentContainerDN = ($DomainParts | ForEach-Object { "DC=$_" }) -join ","


# Define the distinguished name (DN) for the new OU
$NewOUDN = "OU=$ClientOUCustomName,$ParentContainerDN"

# Check if the OU already exists
if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$NewOUDN'" -ErrorAction SilentlyContinue)) {
    # Create the new OU
    New-ADOrganizationalUnit -Name $ClientOUCustomName -Path $ParentContainerDN
    Write-Output "Organizational Unit '$ClientOUCustomName' created successfully under $ParentContainerDN."
} else {
    Write-Output "Organizational Unit '$ClientOUCustomName' already exists under $ParentContainerDN."
}
