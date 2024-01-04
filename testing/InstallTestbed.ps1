param (
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName
)

$VMUsername = "admin.ackbar"
#$ResourceGroupName = "LME-cbaxley-t2"
$VMName = "DC1"
$LinuxVMName = "LS1"

$Password = Get-Content "password.txt"

$libraryPath = Join-Path -Path $PSScriptRoot -ChildPath "configure\azure_scripts\lib\utilityFunctions.ps1"

# Check if the library file exists
if (Test-Path -Path $libraryPath) {
    # Dot-source the library script
    . $libraryPath
} else {
    Write-Error "Library script not found at path: $libraryPath"
}

# Create a container to keep files for the VM
Write-Host "Creating a container to keep files for the VM..."
./configure/azure_scripts/create_blob_container.ps1 `
    -ResourceGroupName $ResourceGroupName

# Source the variables from the file
Write-Host "Sourcing the variables from the file..."
. ./configure/azure_scripts/config.ps1

# Zip up the installer scripts for the VM
Write-Host "Zipping up the installer scripts for the VM..."
./configure/azure_scripts/zip_my_parents_parent.ps1

# Upload the zip file to the container and get a key to download it
Write-Host "Uploading the zip file to the container and getting a key to download it..."
$FileDownloadUrl = ./configure/azure_scripts/copy_file_to_container.ps1 `
    -LocalFilePath "configure.zip" `
    -ContainerName $ContainerName `
    -StorageAccountName $StorageAccountName `
    -StorageAccountKey $StorageAccountKey

Write-Host "File download URL: $FileDownloadUrl"

Write-Host "Changing directory to the azure scripts..."
Set-Location configure/azure_scripts

# Make our directory on the VM
Write-Host "Making our directory on the VM..."
$createDirResponse = az vm run-command invoke `
  --command-id RunPowerShellScript `
  --name $VMName `
  --resource-group $ResourceGroupName `
  --scripts "if (-not (Test-Path -Path 'C:\lme')) { New-Item -Path 'C:\lme' -ItemType Directory }"

Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$createDirResponse")

# Download the zip file to the VM
Write-Host "Downloading the zip file to the VM..."
.\download_in_container.ps1 `
    -VMName $VmName `
    -ResourceGroupName $ResourceGroupName `
    -FileDownloadUrl "$FileDownloadUrl" `
    -DestinationFilePath "configure.zip"

# Extract the zip file
Write-Host "Extracting the zip file..."
.\extract_archive.ps1 `
    -VMName $VMName `
    -ResourceGroupName $ResourceGroupName `
    -FileName "configure.zip"

# Run the install script for chapter 1
Write-Host "Running the install script for chapter 1..."
$installChapter1Response = .\run_script_in_container.ps1 `
    -ResourceGroupName $ResourceGroupName `
    -VMName $VMName `
    -ScriptPathOnVM "C:\lme\configure\install_chapter_1.ps1"
Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$installChapter1Response")

# Todo: Loop these for number of vms
# Update the group policy on the remote machines
Write-Host "Updating the group policy on the remote machines..."
$gpupdateResponse = az vm run-command invoke `
  --command-id RunPowerShellScript `
  --name "C1" `
  --resource-group $ResourceGroupName `
  --scripts "gpupdate /force"
Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$gpupdateResponse")

$gpupdateResponse = az vm run-command invoke `
  --command-id RunPowerShellScript `
  --name "C2" `
  --resource-group $ResourceGroupName `
  --scripts "gpupdate /force"
Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$gpupdateResponse")

# Wait for the services to start
Write-Host "Waiting for the services to start..."
Start-Sleep 20

# See if we can see the forwarding computers in the DC
write-host "Seeing if we can see the forwarding computers in the DC..."
$listForwardingComputersResponse = .\run_script_in_container.ps1 `
    -ResourceGroupName $ResourceGroupName `
    -VMName $VMName `
    -ScriptPathOnVM "C:\lme\configure\list_computers_forwarding_events.ps1"
Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$listForwardingComputersResponse")

# Install the sysmon service on DC1 from chapter 2
Write-Host "Installing the sysmon service on DC1 from chapter 2..."
$installChapter2Response = .\run_script_in_container.ps1 `
    -ResourceGroupName $ResourceGroupName `
    -VMName $VMName `
    -ScriptPathOnVM "C:\lme\configure\install_chapter_2.ps1"
Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$installChapter2Response")

# Update the group policy on the remote machines
Write-Host "Updating the group policy on the remote machines..."
$gpupdateResponse = az vm run-command invoke `
  --command-id RunPowerShellScript `
  --name "C1" `
  --resource-group $ResourceGroupName `
  --scripts "gpupdate /force"
Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$gpupdateResponse")

$gpupdateResponse = az vm run-command invoke `
  --command-id RunPowerShellScript `
  --name "C2" `
  --resource-group $ResourceGroupName `
  --scripts "gpupdate /force"
Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$gpupdateResponse")

# Wait for the services to start
Write-Host "Waiting for the services to start..."
Start-Sleep 20


# See if you can see sysmon running on the machine
Write-Host "Seeing if you can see sysmon running on a machine..."
$showSysmonResponse = az vm run-command invoke `
  --command-id RunPowerShellScript `
  --name "C1" `
  --resource-group $ResourceGroupName `
  --scripts 'Get-Service | Where-Object { $_.DisplayName -like "*Sysmon*" }'
Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$showSysmonResponse")


# Download the installers on LS1
Write-Host "Downloading the installers on LS1..."
.\download_in_container.ps1 `
    -VMName $LinuxVMName `
    -ResourceGroupName $ResourceGroupName `
    -FileDownloadUrl "$FileDownloadUrl" `
    -DestinationFilePath "configure.zip" `
    -os "linux"

# Install unzip on LS1
Write-Host "Installing unzip on LS1..."
$installUnzipResponse = az vm run-command invoke `
  --command-id RunShellScript `
  --name $LinuxVMName `
  --resource-group $ResourceGroupName `
  --scripts 'apt-get install unzip -y'
Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$installUnzipResponse")

# Unzip the file on LS1
Write-Host "Unzipping the file on LS1..."
.\extract_archive.ps1 `
    -VMName $LinuxVMName `
    -ResourceGroupName $ResourceGroupName `
    -FileName "configure.zip" `
    -os "linux"

# Make the installer files executable and update the system packages on LS1
Write-Host "Making the installer files executable and updating the system packages on LS1..."
$updateLinuxResponse = az vm run-command invoke `
  --command-id RunShellScript `
  --name $LinuxVMName `
  --resource-group $ResourceGroupName `
  --scripts 'chmod +x /home/admin.ackbar/lme/configure/* && /home/admin.ackbar/lme/configure/linux_update_system.sh'
Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$updateLinuxResponse")

# Run the lme installer on LS1
Write-Host "Running the lme installer on LS1..."
# Todo: We need to check the output from this and see if we need to reboot
# It should include this line "## logstash_system:" if it completed successfully
$installLmeResponse = az vm run-command invoke `
  --command-id RunShellScript `
  --name $LinuxVMName `
  --resource-group $ResourceGroupName `
  --scripts '/home/admin.ackbar/lme/configure/linux_install_lme.sh'
Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$installLmeResponse")

# Have to check for the reboot thing here
Write-Host "Rebooting ${LinuxVMName}..."
az vm restart `
    --resource-group $ResourceGroupName `
    --name $LinuxVMName

# Run the lme installer on LS1
Write-Host "Running the lme installer on LS1..."
az vm run-command invoke `
  --command-id RunShellScript `
  --name $LinuxVMName `
  --resource-group $ResourceGroupName `
  --scripts '/home/admin.ackbar/lme/configure/linux_install_lme.sh'
Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$installLmeResponse")

# Capture the output of the install script
Write-Host "Capturing the output of the install script for ES passwords..."
$jsonResponse = az vm run-command invoke `
  --command-id RunShellScript `
  --name $LinuxVMName `
  --resource-group $ResourceGroupName `
  --scripts 'tail -n10 "/opt/lme/Chapter 3 Files/output.log" | head -n4'

# Todo: Extract the output and write this to a file for later use
Format-AzVmRunCommandOutput -JsonResponse "$jsonResponse"

# Generate key using expect on linux
Write-Host "Generating key using expect on linux..."
az vm run-command invoke `
  --command-id RunShellScript `
  --name $LinuxVMName `
  --resource-group $ResourceGroupName `
  --scripts '/home/admin.ackbar/lme/configure/linux_make_private_key.exp'

# Add the public key to the authorized_keys file on LS1
Write-Host "Adding the public key to the authorized_keys file on LS1..."
$authorizePrivateKeyResponse = az vm run-command invoke `
  --command-id RunShellScript `
  --name $LinuxVMName `
  --resource-group $ResourceGroupName `
  --scripts '/home/admin.ackbar/lme/configure/linux_authorize_private_key.sh'
Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$authorizePrivateKeyResponse")

# Cat the private key and capture that to the azure shell
Write-Host "Cat the private key and capture that to the azure shell..."
$jsonResponse = az vm run-command invoke `
  --command-id RunShellScript `
  --name $LinuxVMName `
  --resource-group $ResourceGroupName `
  --scripts 'cat /home/admin.ackbar/.ssh/id_rsa'

$privateKey = ExtractPrivateKeyFromJson -jsonResponse "$jsonResponse"

# Save the private key to a file
Write-Host "Saving the private key to a file..."
$filePath = ".\id_rsa"
Set-Content -Path $filePath -Value $privateKey

# Upload the private key to the container and get a key to download it
Write-Host "Uploading the private key to the container and getting a key to download it..."
$KeyDownloadUrl = ./copy_file_to_container.ps1 `
    -LocalFilePath "id_rsa" `
    -ContainerName $ContainerName `
    -StorageAccountName $StorageAccountName `
    -StorageAccountKey $StorageAccountKey

# Download the private key to DC1
Write-Host "Downloading the private key to DC1..."
.\download_in_container.ps1 `
    -VMName $VmName `
    -ResourceGroupName $ResourceGroupName `
    -FileDownloadUrl "$KeyDownloadUrl" `
    -DestinationFilePath "id_rsa"

# Change the ownership of the private key file on DC1
Write-Host "Changing the ownership of the private key file on DC1..."
$chownPrivateKeyResponse = .\run_script_in_container.ps1 `
    -ResourceGroupName $ResourceGroupName `
    -VMName $VMName `
    -ScriptPathOnVM "C:\lme\configure\chown_dc1_private_key.ps1"
Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$chownPrivateKeyResponse")

# Trust the key from ls1 so we can scp interactively
# Todo: We may not need this
#.\run_script_in_container.ps1 `
#    -ResourceGroupName $ResourceGroupName `
#    -VMName $VMName `
#    -ScriptPathOnVM "C:\lme\configure\trust_ls1_ssh_key.ps1"
#

# Use the azure shell to run scp on DC1 to copy the files from LS1 to DC1
Write-Host "Using the azure shell to run scp on DC1 to copy the files from LS1 to DC1..."
$scpResponse = az vm run-command invoke `
    --command-id RunPowerShellScript `
    --name $VMName `
    --resource-group $ResourceGroupName `
    --scripts 'scp -o StrictHostKeyChecking=no -i "C:\lme\id_rsa" admin.ackbar@ls1.lme.local:/home/admin.ackbar/files_for_windows.zip "C:\lme\"'
Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$scpResponse")

# Extract the files on DC1
Write-Host "Extracting the files on DC1..."
.\extract_archive.ps1 `
    -VMName $VMName `
    -ResourceGroupName $ResourceGroupName `
    -FileName "files_for_windows.zip"

# Install winlogbeat on DC1
Write-Host "Installing winlogbeat on DC1..."
$installWinlogbeatResponse = .\run_script_in_container.ps1 `
    -ResourceGroupName $ResourceGroupName `
    -VMName $VMName `
    -ScriptPathOnVM "C:\lme\configure\winlogbeat_install.ps1"

Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$installWinlogbeatResponse")

Write-Host "Insttall completed."
