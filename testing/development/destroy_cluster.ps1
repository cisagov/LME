$ErrorActionPreference = 'Stop'

# Check if the RESOURCE_GROUP environment variable has a value
if ([string]::IsNullOrWhiteSpace($env:RESOURCE_GROUP)) {
    Write-Error "RESOURCE_GROUP environment variable is not set."
    exit 1
}

# Delete the resource group
az group delete --name "$env:RESOURCE_GROUP" --yes --no-wait

Write-Host "Deletion of resource group $($env:RESOURCE_GROUP) initiated."
