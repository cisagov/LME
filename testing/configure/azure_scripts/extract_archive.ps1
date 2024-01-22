<#
.SYNOPSIS
Unzips a file on a specified Azure Virtual Machine.

.DESCRIPTION
This script unzips a specified zip file on an Azure Virtual Machine (VM). It takes the VM's username and a filename (with optional path),
strips the path, constructs the full paths in the VM's 'Downloads' directory, strips the extension from the filename for the extraction path,
and unzips the file. The script requires the VM name, resource group name, username on the VM, and the filename of the zip file.

.PARAMETER VMName
The name of the Azure Virtual Machine where the file will be unzipped.

.PARAMETER ResourceGroup
The name of the Azure Resource Group that contains the VM.

.PARAMETER Filename
The name (and optional path) of the zip file to be unzipped.

.EXAMPLE
.\extract_archive.ps1 `
    -VMName "DC1" `
    -ResourceGroup "YourResourceGroupName" `
    -Filename "filename.zip" `
    -UserName "admin.ackbar" `
    -Os "Windows"

This example unzips 'filename.zip' from the 'Downloads' directory of the user 'username' on the VM "DC1" in the resource group "YourResourceGroupName", and extracts it to a subdirectory named 'filename'.

.NOTES
- Ensure that the Azure CLI is installed and configured with the necessary permissions to access and run commands on the specified Azure VM.
- The VM should have the necessary permissions to read the zip file and write to the extraction directory.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$VMName,

    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true)]
    [string]$Filename,

    [Parameter()]
    [string]$UserName = "admin.ackbar",

    [Parameter()]
    [ValidateSet("Windows","Linux","linux")]
    [string]$Os = "Windows"
)

# Convert the OS parameter to lowercase for consistent comparison
$Os = $Os.ToLower()

# Extract just the filename (ignoring any provided path)
$JustFilename = Split-Path -Leaf $Filename

# Set paths depending on the OS
if ($Os -eq "linux") {
    $ZipFilePath = "/home/$UserName/lme/$JustFilename"
    $FileBaseName = [System.IO.Path]::GetFileNameWithoutExtension($JustFilename)
    $ExtractToPath = "/home/$UserName/lme/$FileBaseName"  # Extract to a subdirectory

    $UnzipScript = @"
    unzip '$ZipFilePath' -d '$ExtractToPath'
"@
} else {
    $ZipFilePath = "C:\lme\$JustFilename"
    $FileBaseName = [System.IO.Path]::GetFileNameWithoutExtension($JustFilename)
    $ExtractToPath = "C:\lme\$FileBaseName"  # Extract to a subdirectory

    $UnzipScript = @"
    Expand-Archive -Path '$ZipFilePath' -DestinationPath '$ExtractToPath'
"@
}

# Execute the unzip script with the appropriate command based on OS
if ($Os -eq "linux") {
    az vm run-command invoke `
        --command-id RunShellScript `
        --resource-group $ResourceGroup `
        --name $VMName `
        --scripts $UnzipScript
} else {
    az vm run-command invoke `
        --command-id RunPowerShellScript `
        --resource-group $ResourceGroup `
        --name $VMName `
        --scripts $UnzipScript
}
