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

# Run the sysmon install scripts
.\sysmon_install_in_sysvol.ps1
.\sysmon_import_gpo.ps1 -directory lme
.\sysmon_gpo_update_vars.ps1
.\sysmon_link_gpo.ps1
