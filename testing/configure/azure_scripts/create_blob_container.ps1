<#
.SYNOPSIS
This script creates a new Azure Storage Account and Blob Container within a specified Azure Resource Group.

.DESCRIPTION
Automates the creation of a unique Azure Storage Account and Blob Container.
Requires the Azure Resource Group name as a mandatory argument.
Generates unique names for the storage account and container, creates the storage account, retrieves the storage account key,
creates a blob container, and saves the configuration to a 'config.ps1' file in the script's directory.

.PARAMETER ResourceGroup
The name of the Azure Resource Group for the storage account and blob container.

.EXAMPLE
.\create_blob_container.ps1 -ResourceGroup "YourResourceGroupName"

Replace "YourResourceGroupName" with the name of your Azure Resource Group.

.NOTES
- Requires Azure CLI and Azure account login.
- Ensure appropriate permissions in Azure.
- Handle the generated 'config.ps1' file securely.

#>


param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup
)

function New-AzureName {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Prefix
    )

    # Ensuring the prefix is lowercase as Azure Storage Account names must be all lowercase
    $Prefix = $Prefix.ToLower()

    # Generate a string of random lowercase letters and numbers
    $randomCharacters = -join ((48..57) + (97..122) | Get-Random -Count (24 - $Prefix.Length) | ForEach-Object { [char]$_ })

    return $Prefix + $randomCharacters
}

# Get the location of the resource group
$Location = (az group show --name $ResourceGroup --query location --output tsv)

# Generate a unique storage account name
$StorageAccountName = New-AzureName -Prefix "st"

# Generate a container name
$ContainerName = New-AzureName -Prefix "container"

# Variables used for Azure tags
$CurrentUser = $(az account show | ConvertFrom-Json).user.name
$Today = $(Get-Date).ToString("yyyy-MM-dd")
$Project = "LME"

# Create a new storage account
az storage account create `
    --name $StorageAccountName `
    --resource-group $ResourceGroup `
    --location $Location `
    --sku Standard_LRS `
    --tags project=$Project created=$Today createdBy=$CurrentUser

# Wait for a moment to ensure the storage account is available
Start-Sleep -Seconds 10

# Get the storage account key
$StorageAccountKey = (az storage account keys list `
    --resource-group $ResourceGroup `
    --account-name $StorageAccountName `
    --query '[0].value' `
    --output tsv)

# Create a blob container
az storage container create `
    --name $ContainerName `
    --account-name $StorageAccountName `
    --account-key $StorageAccountKey

# Output the created resources' details
Write-Output "Created Storage Account: $StorageAccountName"
Write-Output "StorageAccountKey: $StorageAccountKey"
Write-Output "Created Container: $ContainerName"

# Define the file path in the same directory as the running script
$filePath = Join-Path -Path $PSScriptRoot -ChildPath "config.ps1"

# Write the variables as PowerShell script to the file
@"
`$StorageAccountName = '$StorageAccountName'
`$StorageAccountKey = '$StorageAccountKey'
`$ContainerName = '$ContainerName'
"@ | Set-Content -Path $filePath



