param (
    [Parameter(Mandatory=$true)]
    [string]$IPAddress
)

$ErrorActionPreference = 'Stop'

# Log in using Azure CLI
az login --service-principal -u $env:AZURE_CLIENT_ID -p $env:AZURE_SECRET --tenant $env:AZURE_TENANT

# Construct the path to the target directory relative to the script's location
$targetDirectory = Join-Path -Path $PSScriptRoot -ChildPath "..\\"

# Change to the target directory
Set-Location -Path $targetDirectory

# Execute the SetupTestbed.ps1 script with parameters
# TODO: Change to full install before merge
.\SetupTestbed.ps1 -AllowedSources "$IPAddress/32" -l centralus -ResourceGroup $env:RESOURCE_GROUP -y -m | Tee-Object -FilePath "./$env:RESOURCE_GROUP.cluster.output.log"