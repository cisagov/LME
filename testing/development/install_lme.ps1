param(
    [switch]$m,
    [string]$v,
    [string]$b
)

$ErrorActionPreference = 'Stop'

# Check if -v and -b are mutually exclusive
if ($v -and $b) {
    Write-Error "Error: -v and -b are mutually exclusive. Please provide only one of them."
    exit 1
}

# Log in using Azure CLI
az login --service-principal -u $env:AZURE_CLIENT_ID -p $env:AZURE_SECRET --tenant $env:AZURE_TENANT

# Construct the path to the target directory relative to the script's location
$targetDirectory = Join-Path -Path $PSScriptRoot -ChildPath "..\\"

# Change to the target directory
Set-Location -Path $targetDirectory

# Prepare the parameters for InstallTestbed.ps1
$installTestbedParams = "" 
if ($v) {
    $installTestbedParams += " -v $v "
}
if ($b) {
    $installTestbedParams += " -b $b "
}
if ($m) {
    $installTestbedParams += " -m "
}

# Execute the InstallTestbed.ps1 script with parameters
.\InstallTestbed.ps1 -ResourceGroup $env:RESOURCE_GROUP  | Tee-Object -FilePath "./$env:RESOURCE_GROUP.output.log"