param (
    [Alias("g")]
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,

    [Alias("w")]
    [string]$DomainController = "DC1",

    [Alias("l")]
    [string]$LinuxVM = "LS1",

    [Alias("n")]
    [int]$NumClients = 2,

    [Alias("m")]
    [Parameter(
        HelpMessage = "(minimal) Only install the linux server. Useful for testing the linux server without the windows clients"
    )]
    [switch]$LinuxOnly,

    [Alias("v")]
    [string]$Version = $false,

    [Alias("b")]
    [string]$Branch = $false
)

# If you were to need the password from the SetupTestbed.ps1 script, you could use this:
# $Password = Get-Content "${ResourceGroup}.password.txt"

$ProcessSeparator = "`n----------------------------------------`n"

# Define our library path
$LibraryPath = Join-Path -Path $PSScriptRoot -ChildPath "configure\azure_scripts\lib\utilityFunctions.ps1"

# Check if the library file exists
if (Test-Path -Path $LibraryPath) {
    # Dot-source the library script
    . $LibraryPath
}
else {
    Write-Error "Library script not found at path: $LibraryPath"
}

if ($Version -ne $false -and -not ($Version -match '^[0-9]+\.[0-9]+\.[0-9]+$')) {
    Write-Host "Invalid version format: $Version. Expected format: X.Y.Z (e.g., 1.3.0)"
    exit 1
}

# Create a container to keep files for the VM
Write-Output "Creating a container to keep files for the VM..."
$createBlobResponse = ./configure/azure_scripts/create_blob_container.ps1 `
    -ResourceGroup $ResourceGroup
Write-Output $createBlobResponse
Write-Output $ProcessSeparator

# Source the variables from the file
Write-Output "`nSourcing the variables from the file..."
. ./configure/azure_scripts/config.ps1

# Remove old code if it exists
if (Test-Path ./configure.zip) {
    Remove-Item ./configure.zip -Force -Confirm:$false -ErrorAction SilentlyContinue
}

Write-Output $ProcessSeparator

# Zip up the installer scripts for the VM
Write-Output "`nZipping up the installer scripts for the VMs..."
./configure/azure_scripts/zip_my_parents_parent.ps1
Write-Output $ProcessSeparator

# Upload the zip file to the container and get a key to download it
Write-Output "`nUploading the zip file to the container and getting a key to download it..."
$FileDownloadUrl = ./configure/azure_scripts/copy_file_to_container.ps1 `
    -LocalFilePath "configure.zip" `
    -ContainerName $ContainerName `
    -StorageAccountName $StorageAccountName `
    -StorageAccountKey $StorageAccountKey

Write-Output "File download URL: $FileDownloadUrl"
Write-Output $ProcessSeparator

Write-Output "`nChanging directory to the azure scripts..."
Set-Location configure/azure_scripts
Write-Output $ProcessSeparator

if (-Not $LinuxOnly) {
    Write-Output "`nInstalling on the windows clients..."
    # Make our directory on the VM
    Write-Output "`nMaking our directory on the VM..."
    $createDirResponse = az vm run-command invoke `
      --command-id RunPowerShellScript `
      --name $DomainController `
      --resource-group $ResourceGroup `
      --scripts "if (-not (Test-Path -Path 'C:\lme')) { New-Item -Path 'C:\lme' -ItemType Directory }"
    Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$createDirResponse")
    Write-Output $ProcessSeparator

    # Download the zip file to the VM
    Write-Output "`nDownloading the zip file to the VM..."
    $downloadZipFileResponse = .\download_in_container.ps1 `
        -VMName $DomainController `
        -ResourceGroup $ResourceGroup `
        -FileDownloadUrl "$FileDownloadUrl" `
        -DestinationFilePath "configure.zip"
    Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$downloadZipFileResponse")
    Write-Output $ProcessSeparator

    # Extract the zip file
    Write-Output "`nExtracting the zip file..."
    $extractArchiveResponse = .\extract_archive.ps1 `
        -VMName $DomainController `
        -ResourceGroup $ResourceGroup `
        -FileName "configure.zip"
    Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$extractArchiveResponse")
    Write-Output $ProcessSeparator

    # Run the install script for chapter 1
    Write-Output "`nRunning the install script for chapter 1..."
    $installChapter1Response = .\run_script_in_container.ps1 `
        -ResourceGroup $ResourceGroup `
        -VMName $DomainController `
        -ScriptPathOnVM "C:\lme\configure\install_chapter_1.ps1"
    Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$installChapter1Response")
    Write-Output $ProcessSeparator

    # Update the group policy on the remote machines
    Write-Output "`nUpdating the group policy on the remote machines..."
    Invoke-GPUpdateOnVMs -ResourceGroup $ResourceGroup -numberOfClients $NumClients
    Write-Output $ProcessSeparator

    # Wait for the services to start
    Write-Output "`nWaiting for the services to start..."
    Start-Sleep 10

    # See if we can see the forwarding computers in the DC
    write-host "`nChecking if we can see the forwarding computers in the DC..."
    $listForwardingComputersResponse = .\run_script_in_container.ps1 `
        -ResourceGroup $ResourceGroup `
        -VMName $DomainController `
        -ScriptPathOnVM "C:\lme\configure\list_computers_forwarding_events.ps1"
    Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$listForwardingComputersResponse")
    Write-Output $ProcessSeparator

    # Install the sysmon service on DC1 from chapter 2
    Write-Output "`nInstalling the sysmon service on DC1 from chapter 2..."
    $installChapter2Response = .\run_script_in_container.ps1 `
        -ResourceGroup $ResourceGroup `
        -VMName $DomainController `
        -ScriptPathOnVM "C:\lme\configure\install_chapter_2.ps1"
    Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$installChapter2Response")
    Write-Output $ProcessSeparator

    # Update the group policy on the remote machines
    Write-Output "`nUpdating the group policy on the remote machines..."
    Invoke-GPUpdateOnVMs -ResourceGroup $ResourceGroup -numberOfClients $NumClients
    Write-Output $ProcessSeparator

    # Wait for the services to start
    Write-Output "`nWaiting for the services to start. Generally they don't show..."
    Start-Sleep 10

    # See if you can see sysmon running on the machine
    Write-Output "`nSeeing if you can see sysmon running on a machine..."
    $showSysmonResponse = az vm run-command invoke `
      --command-id RunPowerShellScript `
      --name "C1" `
      --resource-group $ResourceGroup `
      --scripts 'Get-Service | Where-Object { $_.DisplayName -like "*Sysmon*" }'
    Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$showSysmonResponse")
    Write-Output $ProcessSeparator
}

Write-Output "`nInstalling on the linux server..."
# Download the installers on LS1
Write-Output "`nDownloading the installers on LS1..."
$downloadLinuxZipFileResponse = .\download_in_container.ps1 `
    -VMName $LinuxVM `
    -ResourceGroup $ResourceGroup `
    -FileDownloadUrl "$FileDownloadUrl" `
    -DestinationFilePath "configure.zip" `
    -os "linux"
Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$downloadLinuxZipFileResponse")
Write-Output $ProcessSeparator

# Install unzip on LS1
Write-Output "`nInstalling unzip on LS1..."
$installUnzipResponse = az vm run-command invoke `
  --command-id RunShellScript `
  --name $LinuxVM `
  --resource-group $ResourceGroup `
  --scripts 'apt-get install unzip -y'
Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$installUnzipResponse")
Write-Output $ProcessSeparator

# Unzip the file on LS1
Write-Output "`nUnzipping the file on LS1..."
$extractLinuxArchiveResponse = .\extract_archive.ps1 `
    -VMName $LinuxVM `
    -ResourceGroup $ResourceGroup `
    -FileName "configure.zip" `
    -Os "Linux"
Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$extractLinuxArchiveResponse")
Write-Output $ProcessSeparator

Write-Output "`nMaking the installer files executable and updating the system packages on LS1..."
$updateLinuxResponse = az vm run-command invoke `
  --command-id RunShellScript `
  --name $LinuxVM `
  --resource-group $ResourceGroup `
  --scripts 'chmod +x /home/admin.ackbar/lme/configure/* && /home/admin.ackbar/lme/configure/linux_update_system.sh'
Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$updateLinuxResponse")
Write-Output $ProcessSeparator

$versionArgument = ""
if ($Branch -ne $false) {
    $versionArgument = " -b '$($Branch)'"
} elseif ($Version -ne $false) {
    $versionArgument = " -v $Version"
}
Write-Output "`nRunning the lme installer on LS1..."
$installLmeResponse = az vm run-command invoke `
  --command-id RunShellScript `
  --name $LinuxVM `
  --resource-group $ResourceGroup `
  --scripts "/home/admin.ackbar/lme/configure/linux_install_lme.sh $versionArgument"
Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$installLmeResponse")
Write-Output $ProcessSeparator

# Check if the response contains the need to reboot
$rebootCheckstring = $installLmeResponse | Out-String
if ($rebootCheckstring -match "reboot is required in order to proceed with the install") {
    # Have to check for the reboot thing here
    Write-Output "`nRebooting ${LinuxVM}..."
    az vm restart `
        --resource-group $ResourceGroup `
        --name $LinuxVM
    Write-Output $ProcessSeparator

    Write-Output "`nRunning the lme installer on LS1..."
    $installLmeResponse = az vm run-command invoke `
        --command-id RunShellScript `
        --name $LinuxVM `
        --resource-group $ResourceGroup `
        --scripts "/home/admin.ackbar/lme/configure/linux_install_lme.sh $versionArgument"
    Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$installLmeResponse")
    Write-Output $ProcessSeparator
}

# Capture the output of the install script
Write-Output "`nCapturing the output of the install script for ES passwords..."
$getElasticsearchPasswordsResponse = az vm run-command invoke `
  --command-id RunShellScript `
  --name $LinuxVM `
  --resource-group $ResourceGroup `
  --scripts 'tail -n14 "/opt/lme/Chapter 3 Files/output.log" | head -n9'

# Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$getElasticsearchPasswordsResponse")
Write-Output $ProcessSeparator

if (-Not $LinuxOnly){
    # Generate key using expect on linux
    Write-Output "`nGenerating key using expect on linux..."
    $generateKeyResponse = az vm run-command invoke `
      --command-id RunShellScript `
      --name $LinuxVM `
      --resource-group $ResourceGroup `
      --scripts '/home/admin.ackbar/lme/configure/linux_make_private_key.exp'
    Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$generateKeyResponse")
    Write-Output $ProcessSeparator

    # Add the public key to the authorized_keys file on LS1
    Write-Output "`nAdding the public key to the authorized_keys file on LS1..."
    $authorizePrivateKeyResponse = az vm run-command invoke `
      --command-id RunShellScript `
      --name $LinuxVM `
      --resource-group $ResourceGroup `
      --scripts '/home/admin.ackbar/lme/configure/linux_authorize_private_key.sh'
    Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$authorizePrivateKeyResponse")
    Write-Output $ProcessSeparator

    # Cat the private key and capture that to the azure shell
    Write-Output "`nCat the private key and capture that to the azure shell..."
    $jsonResponse = az vm run-command invoke `
      --command-id RunShellScript `
      --name $LinuxVM `
      --resource-group $ResourceGroup `
      --scripts 'cat /home/admin.ackbar/.ssh/id_rsa'
    $privateKey = Get-PrivateKeyFromJson -jsonResponse "$jsonResponse"

    # Save the private key to a file
    Write-Output "`nSaving the private key to a file..."
    $privateKeyPath = ".\id_rsa"
    Set-Content -Path $privateKeyPath -Value $privateKey
    Write-Output $ProcessSeparator

    # Upload the private key to the container and get a key to download it
    Write-Output "`nUploading the private key to the container and getting a key to download it..."
    $KeyDownloadUrl = ./copy_file_to_container.ps1 `
        -LocalFilePath "id_rsa" `
        -ContainerName $ContainerName `
        -StorageAccountName $StorageAccountName `
        -StorageAccountKey $StorageAccountKey

    # Download the private key to DC1
    Write-Output "`nDownloading the private key to DC1..."
    $downloadPrivateKeyResponse = .\download_in_container.ps1 `
        -VMName $DomainController `
        -ResourceGroup $ResourceGroup `
        -FileDownloadUrl "$KeyDownloadUrl" `
        -DestinationFilePath "id_rsa"
    Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$downloadPrivateKeyResponse")
    Write-Output $ProcessSeparator

    # Change the ownership of the private key file on DC1
    Write-Output "`nChanging the ownership of the private key file on DC1..."
    $chownPrivateKeyResponse = .\run_script_in_container.ps1 `
        -ResourceGroup $ResourceGroup `
        -VMName $DomainController `
        -ScriptPathOnVM "C:\lme\configure\chown_dc1_private_key.ps1"
    Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$chownPrivateKeyResponse")
    Write-Output $ProcessSeparator

    # Remove the private key from the local machine
    Remove-Item -Path $privateKeyPath

    # Use the azure shell to run scp on DC1 to copy the files from LS1 to DC1
    Write-Output "`nUsing the azure shell to run scp on DC1 to copy the files from LS1 to DC1..."
    $scpResponse = az vm run-command invoke `
        --command-id RunPowerShellScript `
        --name $DomainController `
        --resource-group $ResourceGroup `
        --scripts 'scp -o StrictHostKeyChecking=no -i "C:\lme\id_rsa" admin.ackbar@ls1:/home/admin.ackbar/files_for_windows.zip "C:\lme\"'
    Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$scpResponse")
    Write-Output $ProcessSeparator

    # Extract the files on DC1
    Write-Output "`nExtracting the files on DC1..."
    $extractFilesForWindowsResponse = .\extract_archive.ps1 `
        -VMName $DomainController `
        -ResourceGroup $ResourceGroup `
        -FileName "files_for_windows.zip"
    Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$extractFilesForWindowsResponse")
    Write-Output $ProcessSeparator

    # Install winlogbeat on DC1
    Write-Output "`nInstalling winlogbeat on DC1..."
    $installWinlogbeatResponse = .\run_script_in_container.ps1 `
        -ResourceGroup $ResourceGroup `
        -VMName $DomainController `
        -ScriptPathOnVM "C:\lme\configure\winlogbeat_install.ps1"

    Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$installWinlogbeatResponse")
    Write-Output $ProcessSeparator
}


Write-Output "`nRunning the tests for lme on LS1..."
$runTestResponse = az vm run-command invoke `
  --command-id RunShellScript `
  --name $LinuxVM `
  --resource-group  $ResourceGroup `
  --scripts '/home/admin.ackbar/lme/configure/linux_test_install.sh' | ConvertFrom-Json

$message = $runTestResponse.value[0].message
Write-Host "$message`n"
Write-Host "--------------------------------------------"

# Check if there is stderr content in the message field
if ($message -match '\[stderr\]\n(.+)$') {
    Write-Host "Tests failed"
    exit 1
} else {
    Write-Host "Tests succeeded"
}

Write-Output "`nInstall completed."

$EsPasswords = (Format-AzVmRunCommandOutput -JsonResponse "$getElasticsearchPasswordsResponse")[0].StdOut
# Output the passwords
$EsPasswords

# Write the passwords to a file
$PasswordPath = "..\..\${ResourceGroup}.password.txt"
$EsPasswords | Out-File -Append -FilePath $PasswordPath