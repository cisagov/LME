$ErrorActionPreference = 'Stop'

# Log in using Azure CLI
az login --service-principal -u $env:AZURE_CLIENT_ID -p $env:AZURE_SECRET --tenant $env:AZURE_TENANT

# Construct the path to the target directory relative to the script's location
$targetDirectory = Join-Path -Path $PSScriptRoot -ChildPath "..\\"

# Change to the target directory
Set-Location -Path $targetDirectory

# Execute the InstallTestbed.ps1 script with parameters
.\InstallTestbed.ps1 -ResourceGroup $env:RESOURCE_GROUP   | Tee-Object -FilePath "./$env:RESOURCE_GROUP.output.log"