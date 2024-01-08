<#
    Creates a "blank slate" for testing/configuring LME.

    Creates the following:
    - A resource group
    - A virtual network, subnet, and network security group
    - 2 VMs: "DC1," a Windows server, and "LS1," a Linux server
    - Client VMs: Windows clients "C1", "C2", etc. up to 16 based on user input
    - Promotes DC1 to a domain controller
    - Adds "C" clients to the managed domain
    - Adds a DNS entry pointing to LS1

    This script should do all the work for you, simply specify a new resource group,
    the number of desired clients, and optionally Auto-shutdown configuration
    each time you run it. Be sure to copy the username/password it outputs at the end.
    After completion, login to the VMs using RDP (for the Windows machines) or ssh (for the
    linux server) to configure/test LME.
#>

param (
  [Parameter(
    HelpMessage="Auto-Shutdown time in UTC (HHMM, e.g. 2230, 0000, 1900). Convert timezone as necesary: (e.g. 05:30 pm ET -> 9:30 pm UTC -> 21:30 -> 2130)"
  )]
  $AutoShutdownTime=$null,

  [Parameter(
    HelpMessage="Auto-shutdown notification email"
  )]
  $AutoShutdownEmail=$null,

  [Alias("l")]
  [Parameter(
    HelpMessage="Location where the cluster will be built. Default westus"
  )]
  [string]$Location="westus",

  [Alias("g")]
  [Parameter(Mandatory=$true)]
  [string]$ResourceGroup,

  [Alias("n")]
  [Parameter(
    HelpMessage="Number of clients to create (Max: 16)"
  )]
  [int]$NumClients=1,

  [Alias("s")]
  [Parameter(Mandatory=$true,
    HelpMessage="XX.XX.XX.XX/YY,XX.XX.XX.XX/YY,etc... Comma-Separated list of CIDR prefixes or IP ranges"
  )]
  [string]$AllowedSources,

  [Alias("y")]
  [Parameter(
    HelpMessage="Run the script with no prompt (useful for automated runs)"
  )]
  [switch]$NoPrompt
)

# Define our library path
$libraryPath = Join-Path -Path $PSScriptRoot -ChildPath "configure\azure_scripts\lib\utilityFunctions.ps1"

# Check if the library file exists
if (Test-Path -Path $libraryPath) {
    # Dot-source the library script
    . $libraryPath
}
else {
    Write-Error "Library script not found at path: $libraryPath"
}


#DEFAULTS:
#Desired Netowrk Mapping:
$VNetPrefix = "10.1.0.0/16"
$SubnetPrefix = "10.1.0.0/24"
$DcIP = "10.1.0.4"
$LsIP = "10.1.0.5"

#Default Azure Region:
# $Location = "westus"

#Domain information:
$VMAdmin = "admin.ackbar"
$DomainName = "lme.local"

#Port options: https://learn.microsoft.com/en-us/cli/azure/network/nsg/rule?view=azure-cli-latest#az-network-nsg-rule-create
$Ports = 22,3389
$Priorities = 1001,1002
$Protocols = "Tcp","Tcp"


function Get-RandomPassword {
    param (
        [Parameter(Mandatory)]
        [int]$Length
    )
    $TokenSet = @{
        L = [Char[]]'abcdefghijkmnopqrstuvwxyz'
        U = [Char[]]'ABCDEFGHIJKMNPQRSTUVWXYZ'
        N = [Char[]]'23456789'
    }

    $Lower = Get-Random -Count 5 -InputObject $TokenSet.L
    $Upper = Get-Random -Count 5 -InputObject $TokenSet.U
    $Number = Get-Random -Count 5 -InputObject $TokenSet.N

    $StringSet = $Lower + $Number + $Upper

    (Get-Random -Count $Length -InputObject $StringSet) -join ''
}

function Set-AutoShutdown {
    param (
        [Parameter(Mandatory)]
        [string]$VMName
    )

    Write-Output "`nCreating Auto-Shutdown Rule for $VMName at time $AutoShutdownTime..."
    if ($null -ne $AutoShutdownEmail) {
      az vm auto-shutdown `
          -g $ResourceGroup `
          -n $VMName `
          --time $AutoShutdownTime `
          --email $AutoShutdownEmail
    }
    else {
      az vm auto-shutdown `
        -g $ResourceGroup `
        -n $VMName `
        --time $AutoShutdownTime
    }
}

function Set-NetworkRules {
  param (
      [Parameter(Mandatory)]
      $AllowedSourcesList
  )

  if ($Ports.length -ne $Priorities.length){
    Write-Output "Priorities and Ports length should be equal!"
    exit -1
  }
  if ($Ports.length -ne $Protocols.length){
    Write-Output "Protocols and Ports length should be equal!"
    exit -1
  }

  for ($i = 0; $i -le $Ports.length - 1 ; $i++) {
    $port=$Ports[$i]
    $priority=$Priorities[$i]
    $protocol=$Protocols[$i]
    Write-Output "`nCreating Network Port $port rule..."

    az network nsg rule create --name Network_Port_Rule_$port `
        --resource-group $ResourceGroup `
        --nsg-name NSG1 `
        --priority $priority `
        --direction Inbound `
        --access Allow `
        --protocol $protocol `
        --source-address-prefixes $AllowedSourcesList `
        --destination-address-prefixes '*' `
        --destination-port-ranges $port `
        --description "Allow inbound from $sources on $port via $protocol connections."
  }
}


########################
# Validation of Globals #
########################
$AllowedSourcesList = $AllowedSources -Split ","
if ($AllowedSourcesList.length -lt 1){
  Write-Output "**ERROR**: Variable AllowedSources must be set (set with -AllowedSources or -s)"
  exit -1
}

if ($null -ne $AutoShutdownTime) {
  if ( -not ( $AutoShutdownTime -match '^([01][0-9]|2[0-3])[0-5][0-9]$' ) ){
        Write-Output "**ERROR** Invalid time"
        Write-Output "Enter the Auto-Shutdown time in UTC (HHMM, e.g. 2230, 0000, 1900), `n`tConvert timezone as necesary: (e.g. 05:30 pm ET -> 9:30 pm UTC -> 21:30 -> 2130)"
        exit -1
  }
}

if ($NumClients -lt 1 -or $NumClients -gt 16) {
        Write-Output "The number of clients must be at least 1 and no more than 16."
    $NumClients = $NumClients -as [int]
    exit -1
}

################
# Confirmation #
################
Write-Output "Supplied configuration:`n"

Write-Output "Location: $Location"
Write-Output "Resource group: $ResourceGroup"
Write-Output "Number of clients: $NumClients"
Write-Output "Allowed sources (IP's): $AllowedSourcesList"
Write-Output "Auto-shutdown time: $AutoShutdownTime"
Write-Output "Auto-shutdown e-mail: $AutoShutdownEmail"

if (-Not $NoPrompt) {
  do {
    $Proceed = Read-Host "`nProceed? (Y/n)"
  } until ($Proceed -eq "y" -or $Proceed -eq "Y" -or $Proceed -eq "n" -or $Proceed -eq "N")

  if ($Proceed -eq "n" -or $Proceed -eq "N") {
    Write-Output "Setup canceled"
    exit
  }
}

########################
# Setup resource group #
########################
Write-Output "`nCreating resource group..."
az group create --name $ResourceGroup --location $Location

#################
# Setup network #
#################

Write-Output "`nCreating virtual network..."
az network vnet create --resource-group $ResourceGroup `
    --name VNet1 `
    --address-prefix $VNetPrefix `
    --subnet-name SNet1 `
    --subnet-prefix $SubnetPrefix

Write-Output "`nCreating nsg..."
az network nsg create --name NSG1 `
    --resource-group $ResourceGroup `
    --location $Location

Set-NetworkRules -AllowedSourcesList $AllowedSourcesList

##################
# Create the VMs #
##################
$VMPassword = Get-RandomPassword 12
Write-Output "`nWriting $VMAdmin password to ${ResourceGroup}.password.txt"
echo $VMPassword > "${ResourceGroup}.password.txt"

Write-Output "`nCreating DC1..."
az vm create `
    --name DC1 `
    --resource-group $ResourceGroup `
    --nsg NSG1 `
    --image Win2019Datacenter `
    --admin-username $VMAdmin `
    --admin-password $VMPassword `
    --vnet-name VNet1 `
    --subnet SNet1 `
    --public-ip-sku Standard `
    --private-ip-address $DcIP

Write-Output "`nCreating LS1..."
az vm create `
    --name LS1 `
    --resource-group $ResourceGroup `
    --nsg NSG1 `
    --image Ubuntu2204 `
    --admin-username $VMAdmin `
    --admin-password $VMPassword `
    --vnet-name VNet1 `
    --subnet SNet1 `
    --public-ip-sku Standard `
    --size Standard_E2d_v4 `
    --os-disk-size-gb 128 `
    --private-ip-address $LsIP

for ($i = 1; $i -le $NumClients; $i++) {
    Write-Output "`nCreating C$i..."
    az vm create `
        --name C$i `
        --resource-group $ResourceGroup `
        --nsg NSG1 `
        --image Win2019Datacenter `
        --admin-username $VMAdmin `
        --admin-password $VMPassword `
        --vnet-name VNet1 `
        --subnet SNet1 `
        --public-ip-sku Standard
}

###########################
# Configure Auto-Shutdown #
###########################

if ($null -ne $AutoShutdownTime) {
    Set-AutoShutdown "DC1"
    Set-AutoShutdown "LS1"
    for ($i = 1; $i -le $NumClients; $i++) {
        Set-AutoShutdown "C$i"
    }
}

####################
# Setup the domain #
####################
Write-Output "`nInstalling AD Domain services on DC1..."
az vm run-command invoke `
    --command-id RunPowerShellScript `
    --resource-group $ResourceGroup `
    --name DC1 `
    --scripts "Add-WindowsFeature AD-Domain-Services -IncludeManagementTools"

Write-Output "`nRestarting DC1..."
az vm restart `
    --resource-group $ResourceGroup `
    --name DC1 `

Write-Output "`nCreating the ADDS forest..."
az vm run-command invoke `
    --command-id RunPowerShellScript `
    --resource-group $ResourceGroup `
    --name DC1 `
    --scripts "`$Password = ConvertTo-SecureString `"$VMPassword`" -AsPlainText -Force; `
Install-ADDSForest -DomainName $DomainName -Force -SafeModeAdministratorPassword `$Password"

Write-Output "`nRestarting DC1..."
az vm restart `
    --resource-group $ResourceGroup `
    --name DC1 `

for ($i = 1; $i -le $NumClients; $i++) {
    Write-Output "`nAdding DC IP address to C$i host file..."
    az vm run-command invoke `
        --command-id RunPowerShellScript `
        --resource-group $ResourceGroup `
        --name C$i `
        --scripts "Add-Content -Path `$env:windir\System32\drivers\etc\hosts -Value `"`n$DcIP`t$DomainName`" -Force"

    Write-Output "`nSetting C$i DNS server to DC1..."
    az vm run-command invoke `
        --command-id RunPowerShellScript `
        --resource-group $ResourceGroup `
        --name C$i `
        --scripts "Get-Netadapter | Set-DnsClientServerAddress -ServerAddresses $DcIP"

    Write-Output "`nRestarting C$i..."
    az vm restart `
        --resource-group $ResourceGroup `
        --name C$i `

    Write-Output "`nAdding C$i to the domain..."
    az vm run-command invoke `
        --command-id RunPowerShellScript `
        --resource-group $ResourceGroup `
        --name C$i `
        --scripts "`$Password = ConvertTo-SecureString `"$VMPassword`" -AsPlainText -Force; `
    `$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $DomainName\$VMAdmin, `$Password; `
    Add-Computer -DomainName $DomainName -Credential `$Credential -Restart"

    # The following command fixes this issue:
    # https://serverfault.com/questions/754012/windows-10-unable-to-access-sysvol-and-netlogon
    Write-Output "`nModifying C$i register to allow access to sysvol..."
    az vm run-command invoke `
        --command-id RunPowerShellScript `
        --resource-group $ResourceGroup `
        --name C$i `
        --scripts "cmd.exe /c `"%COMSPEC% /C reg add HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\NetworkProvider\HardenedPaths /v \\*\SYSVOL /d RequireMutualAuthentication=0 /t REG_SZ`""
}

Write-Output "`nVM login info:"
Write-Output "Username: $($VMAdmin)"
Write-Output "Password: $($VMPassword)"
Write-Output "SAVE THE ABOVE INFO`n"

Write-Output "`nAdding DNS entry for Linux server..."
Write-Warning "NOTE: Sometimes this final call hangs indefinitely.
Haven't figured out why. If it doesn't finish after a few minutes,
hit ctrl+c to kill the process. Even if it didn't exit normally,
it is likely that the DNS entry was still successfully added. To
verify, log on to DC1 and run 'Resolve-DnsName ls1' in PowerShell.
If it returns NXDOMAIN, you'll need to add it manually."
Write-Output "The time is $(Get-Date)."

# Define the PowerShell script with the DomainName variable interpolated
$scriptContent = @"
`$scriptBlock = {
    Add-DnsServerResourceRecordA -Name LS1 -ZoneName $DomainName -AllowUpdateAny -IPv4Address $LsIP -TimeToLive 01:00:00
}
`$job = Start-Job -ScriptBlock `$scriptBlock
`$timeout = 30
if (Wait-Job -Job `$job -Timeout `$timeout) {
    Receive-Job -Job `$job
    Write-Host 'The script completed within the timeout period.'
} else {
    Stop-Job -Job `$job
    Remove-Job -Job `$job
    Write-Host 'The script timed out after `$timeout seconds.'
}
"@

# Convert the script to a Base64-encoded string
$bytes = [System.Text.Encoding]::Unicode.GetBytes($scriptContent)
$encodedScript = [Convert]::ToBase64String($bytes)


# Run the encoded script on the Azure VM
Write-Output "`nAdding script to add DNS entry for Linux server. No output expected..."
$createDnsScriptResponse = az vm run-command invoke `
    --command-id RunPowerShellScript `
    --name DC1 `
    --resource-group $ResourceGroup `
    --scripts "Set-Content -Path 'C:\AddDnsRecord.ps1' -Value ([System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String('$encodedScript')))"

Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$createDnsScriptResponse")


Write-Output "`nRunning script to add DNS entry for Linux server. It could time out or not. Check output of the next command..."
$addDnsRecordResponse = az vm run-command invoke `
    --command-id RunPowerShellScript `
    --name DC1 `
    --resource-group $ResourceGroup `
    --scripts "C:\AddDnsRecord.ps1"
Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$addDnsRecordResponse")

Write-Host "Checking if ls1 resolves..."
$resolveLs1Response = az vm run-command invoke `
    --command-id RunPowerShellScript `
    --resource-group $ResourceGroup `
    --name DC1 `
    --scripts "Resolve-DnsName ls1"
Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$resolveLs1Response")

Write-Host "Removing the Dns script. No output expected..."
$removeDnsRecordScriptResponse = az vm run-command invoke `
    --command-id RunPowerShellScript `
    --name DC1 `
    --resource-group $ResourceGroup `
    --scripts "Remove-Item -Path 'C:\AddDnsRecord.ps1' -Force"
Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$removeDnsRecordScriptResponse")


Write-Output "Done."
