$ErrorActionPreference = 'Stop'

# Check if the RESOURCE_GROUP environment variable has a value
if ([string]::IsNullOrWhiteSpace($env:RESOURCE_GROUP)) {
    Write-Error "RESOURCE_GROUP environment variable is not set."
    exit 1
}

# Check if the resource group exists
$resourceGroupExists = az group exists --name "$env:RESOURCE_GROUP"

if ($resourceGroupExists -eq 'true') {
    # Delete the resource group if it exists
    az group delete --name "$env:RESOURCE_GROUP" --yes --no-wait
    Write-Output "Deletion of resource group $($env:RESOURCE_GROUP) initiated."
} else {
    Write-Output "Resource group $($env:RESOURCE_GROUP) does not exist. No action taken."
}
