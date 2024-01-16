param (
    [Parameter(
        HelpMessage="Path to the configuration directory. Default is 'C:\lme\configure'."
    )]
    [string]$ConfigurePath = "C:\lme\configure",
    [Parameter(
    HelpMessage="Path to the root install directory. Default is 'C:\lme'."
    )]
    [string]$RootInstallDir = "C:\lme"

)

# Exit the script on any error
$ErrorActionPreference = 'Stop'
$ProcessSeparator = "`n----------------------------------------`n"

# Change directory to the configure directory
Set-Location -Path $ConfigurePath

# Run the scripts and check for failure
Write-Output "Creating the configurePath directory..."
.\create_lme_directory.ps1 -DirectoryPath $RootInstallDir
Write-Output $ProcessSeparator

Write-Output "Downloading the files..."
.\download_files.ps1 -Directory lme
Write-Output $ProcessSeparator

Write-Output "Importing the GPOs..."
.\wec_import_gpo.ps1 -Directory lme
Write-Output $ProcessSeparator

Start-Sleep 10
Write-Output "Updating the GPO server name..."
.\wec_gpo_update_server_name.ps1
Write-Output $ProcessSeparator

Write-Output "Creating the OU..."
.\create_ou.ps1
Write-Output $ProcessSeparator

Write-Output "Linking the GPOs..."
.\wec_link_gpo.ps1
Write-Output $ProcessSeparator

Write-Output "Provisioning the WEC service..."
.\wec_service_provisioner.ps1
Write-Output $ProcessSeparator

# Run the wevtutil and wecutil commands
Write-Output "Running wevtutil and wecutil commands to start the wec service manually..."
wevtutil set-log ForwardedEvents /q:true /e:true
Write-Output $ProcessSeparator

Write-Output "Running wecutil restart command..."
wecutil rs lme
Write-Output $ProcessSeparator

Write-Output "Running wecutil gr command..."
wecutil gr lme
Write-Output $ProcessSeparator

# Run the move_computers_to_ou script
Write-Output "Moving the computers to the OU..."
.\move_computers_to_ou.ps1
