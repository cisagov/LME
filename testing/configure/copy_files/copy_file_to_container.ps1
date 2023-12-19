<#
.SYNOPSIS
Uploads a file to an Azure Blob Storage container and outputs the SAS URL.

.DESCRIPTION
This script uploads a specified file to a given Azure Blob Storage container and generates a Shared Access Signature (SAS) URL for the uploaded item.
It requires the local file path, container name, storage account name, and storage account key as mandatory parameters.
This script is useful for automating the process of uploading files to Azure Blob Storage and obtaining a SAS URL for accessing the uploaded file.

.PARAMETER LocalFilePath
The full local file path of the file to be uploaded.

.PARAMETER ContainerName
The name of the Azure Blob Storage container where the file will be uploaded.

.PARAMETER StorageAccountName
The name of the Azure Storage account.

.PARAMETER StorageAccountKey
The key for the Azure Storage account.

.OUTPUTS
Shared Access Signature (SAS) URL of the uploaded file.

.EXAMPLE
.\copy_file_to_container.ps1 -LocalFilePath "C:\path\to\file.txt" -ContainerName "examplecontainer" -StorageAccountName "examplestorageaccount" -StorageAccountKey "examplekey"

This example uploads 'file.txt' from the local path to 'examplecontainer' in the Azure Storage account named 'examplestorageaccount' and outputs the SAS URL for the uploaded file.

.NOTES
- Ensure that the Azure CLI is installed and configured with the necessary permissions to access the specified Azure Storage account and container.
- The SAS URL provides access to the file with read permissions and is valid for 1 day.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$LocalFilePath,

    [Parameter(Mandatory = $true)]
    [string]$ContainerName,

    [Parameter(Mandatory = $true)]
    [string]$StorageAccountName,

    [Parameter(Mandatory = $true)]
    [string]$StorageAccountKey
)

# Upload file to the blob container
az storage blob upload `
    --container-name $ContainerName `
    --file $LocalFilePath `
    --name (Split-Path $LocalFilePath -Leaf) `
    --account-name $StorageAccountName `
    --account-key $StorageAccountKey `
    --overwrite `


$BlobName = (Split-Path $LocalFilePath -Leaf)
$ExpiryTime = (Get-Date).AddDays(1).ToString('yyyy-MM-ddTHH:mm:ssZ')

# Generate SAS URL for the blob
$SasUrl = az storage blob generate-sas `
    --account-name $StorageAccountName `
    --account-key $StorageAccountKey `
    --container-name $ContainerName `
    --name $BlobName `
    --permissions r `
    --expiry $ExpiryTime `
    --output tsv

# Set the full url var for returing to the user for use in the next script
$ContainerUrl = "https://$StorageAccountName.blob.core.windows.net/$ContainerName/$BlobName?$SasUrl"

$ContainerUrl
