param (
    [Parameter(
        HelpMessage="Path to the configuration directory. Default is 'C:\lme\configure'."
    )]
    [string]$ConfigurePath = "C:\lme\configure"
)

# Exit the script on any error
$ErrorActionPreference = 'Stop'
$ProcessSeparator = "`n----------------------------------------`n"

# Change directory to the configure directory
Set-Location -Path $ConfigurePath

Write-Output "Installing Sysmon..."
.\sysmon_install_in_sysvol.ps1
Write-Output $ProcessSeparator

Write-Output "Importing the gpo..."
.\sysmon_import_gpo.ps1 -Directory lme
Write-Output $ProcessSeparator

Write-Output "Updating the gpo variables.."
.\sysmon_gpo_update_vars.ps1
Write-Output $ProcessSeparator

Write-Output "Linking the gpo..."
.\sysmon_link_gpo.ps1
