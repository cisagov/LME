<#
.SYNOPSIS
Downloads a file to a specified Azure VM's user directory.

.DESCRIPTION
This script downloads a file from a given URL to a specified Azure Virtual Machine (VM).
It places the file in the Downloads directory of a specified user's profile on the VM.
The script requires details of the VM, the resource group, the file URL, the local filename for saving,
and the VM's username.

.PARAMETER VMName
The name of the Azure Virtual Machine.

.PARAMETER ResourceGroupName
The name of the Azure Resource Group that contains the VM.

.PARAMETER FileDownloadUrl
The URL of the file to be downloaded.

.PARAMETER DestinationFilePath
The local file path where the file will be saved. Only the filename is used.

.EXAMPLE
.\download_in_container.ps1 `
    -VMName "DC1" `
    -ResourceGroupName "YourResourceGroupName" `
    -FileDownloadUrl "http://example.com/file.ext" `
    -DestinationFilePath "filename.ext"

This example downloads a file from "http://example.com/file.ext" to the "Downloads" directory of the user "username" on the VM "DC1" in the resource group "YourResourceGroupName".

.NOTES
Ensure that the Azure CLI is installed and configured with the necessary permissions to access the specified Azure VM.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$VMName,

    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$true)]
    [string]$FileDownloadUrl,

    [Parameter(Mandatory=$true)]
    [string]$DestinationFilePath  # This will be stripped to only the filename
)

# Extract just the filename from the destination file path
$DestinationFileName = Split-Path -Leaf $DestinationFilePath

# Set the destination path in the VM's user Downloads directory
$DestinationPath = "C:\lme\$DestinationFileName"

$DownloadScript = @"
Invoke-WebRequest -Uri '$FileDownloadUrl' -OutFile '$DestinationPath'
"@

az vm run-command invoke `
    --command-id RunPowerShellScript `
    --resource-group $ResourceGroupName `
    --name $VMName `
    --scripts $DownloadScript
