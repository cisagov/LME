<#
.SYNOPSIS
This script automates the file download process on a specified VM based on its OS type.

.DESCRIPTION
The script takes parameters for VM name, resource group, file URL, destination file path, username, and OS type. It processes these parameters to download a file to a VM, either running Windows or Linux. The script determines the appropriate command to create a directory (if necessary) and download the file to the specified VM, handling differences in command syntax and file path conventions based on the OS.

.PARAMETER VMName
The name of the Virtual Machine where the file will be downloaded.

.PARAMETER ResourceGroupName
The name of the Azure resource group where the VM is located.

.PARAMETER FileDownloadUrl
The URL of the file to be downloaded.

.PARAMETER DestinationFilePath
The complete path where the file should be downloaded on the VM. This path is processed to extract just the filename.

.PARAMETER username
The username for the VM, used in constructing the file path for Linux systems. Default is 'admin.ackbar'.

.PARAMETER os
The operating system type of the VM. Accepts 'Windows', 'Linux', or 'linux'. Default is 'Windows'.

.EXAMPLE
.\download_in_container.ps1 `
    -VMName "MyVM" `
    -ResourceGroupName "MyResourceGroup" `
    -FileDownloadUrl "http://example.com/file.zip" `
    -DestinationFilePath "C:\path\to\file.zip"

This example downloads a file from 'http://example.com/file.zip' to 'C:\path\to\file.zip'
 on the VM named 'MyVM' in the 'MyResourceGroup'.

.NOTES
- Ensure that the Azure CLI is installed and configured with the necessary permissions to access and run commands on the specified Azure VM.
- The specified script must exist on the VM and the VM should have the necessary permissions to execute it.

 #>
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$VMName,

    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$true)]
    [string]$FileDownloadUrl,

    [Parameter(Mandatory=$true)]
    [string]$DestinationFilePath,  # This will be stripped to only the filename

    [Parameter()]
    [string]$username = "admin.ackbar",

    [Parameter()]
    [ValidateSet("Windows","Linux","linux")]
    [string]$os = "Windows"
)

# Convert the OS parameter to lowercase for consistent comparison
$os = $os.ToLower()

# Extract just the filename from the destination file path
$DestinationFileName = Split-Path -Leaf $DestinationFilePath

# Set the destination path depending on the OS
if ($os -eq "linux") {
    $DestinationPath = "/home/$username/lme/$DestinationFileName"
    # Create the lme directory if it doesn't exist
    $DirectoryCreationScript = "mkdir -p '/home/$username/lme'"
    az vm run-command invoke `
        --command-id RunShellScript `
        --resource-group $ResourceGroupName `
        --name $VMName `
        --scripts $DirectoryCreationScript
} else {
    $DestinationPath = "C:\lme\$DestinationFileName"
}

# The download script
$DownloadScript = if ($os -eq "linux") {
    "curl -o '$DestinationPath' '$FileDownloadUrl'"
} else {
    "Invoke-WebRequest -Uri '$FileDownloadUrl' -OutFile '$DestinationPath'"
}

# Execute the download script with the appropriate command based on OS
if ($os -eq "linux") {
    az vm run-command invoke `
        --command-id RunShellScript `
        --resource-group $ResourceGroupName `
        --name $VMName `
        --scripts $DownloadScript
} else {
    az vm run-command invoke `
        --command-id RunPowerShellScript `
        --resource-group $ResourceGroupName `
        --name $VMName `
        --scripts $DownloadScript
}
