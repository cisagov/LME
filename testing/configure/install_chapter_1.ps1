param (
    [Parameter(
        HelpMessage="Path to the configuration directory. Default is 'C:\lme\configure'."
    )]
    [string]$configurePath = "C:\lme\configure"
)

# Exit the script on any error
$ErrorActionPreference = 'Stop'

# Change directory to the configure directory
Set-Location -Path $configurePath

# Run the scripts and check for failure
.\copy_files\create_lme_directory.ps1
.\download_files.ps1 -directory lme
.\wec_import_gpo.ps1 -directory lme
.\wec_gpo_update_server_name.ps1
.\create_ou.ps1
.\wec_link_gpo.ps1
.\wec_service_provisioner.ps1

# Run the wevtutil and wecutil commands
wevtutil set-log ForwardedEvents /q:true /e:true
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
wecutil rs lme
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
wecutil gr lme
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Run the move_computers_to_ou script
.\move_computers_to_ou.ps1
