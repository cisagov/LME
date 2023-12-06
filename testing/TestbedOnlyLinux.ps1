<#
    Creates a "blank slate" for testing/configuring LME.

    Creates the following:
    - A resource group
    - A virtual network, subnet, and network security group
    - "LS1," a Linux server

    This script should do all the work for you, simply specify a new resource group,
    and optionally Auto-shutdown configuration each time you run it. 
    Be sure to copy the username/password it outputs at the end.
    After completion, login to the VMs using ssh to configure/test LME.

    Example: ./TestbedOnlyLinux.ps1 -Location centralus -ResourceGroup YourResourceGroup -AutoShutdownTime 0000 -AllowedSources "x.x.x.x/32" -y
#>

param (
    [Parameter(
            HelpMessage = "Auto-Shutdown time in UTC (HHMM, e.g. 2230, 0000, 1900). Convert timezone as necesary: (e.g. 05:30 pm ET -> 9:30 pm UTC -> 21:30 -> 2130)"
    )]
    $AutoShutdownTime = $null,

    [Parameter(
            HelpMessage = "Auto-shutdown notification email"
    )]
    $AutoShutdownEmail = $null,

    [Alias("l")]
    [Parameter(
            HelpMessage = "Location where the cluster will be built. Default westus"
    )]
    [string]$Location = "westus",

    [Alias("g")]
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,

    [Alias("s")]
    [Parameter(Mandatory = $true,
            HelpMessage = "XX.XX.XX.XX/YY,XX.XX.XX.XX/YY,etc... Comma-Separated list of CIDR prefixes or IP ranges to whitelist"
    )]
    [string]$AllowedSources,

    [Alias("y")]
    [Parameter(
            HelpMessage = "Run the script with no prompt (useful for automated runs)"
    )]
    [switch]$NoPrompt
)

#DEFAULTS:
#Desired Netowrk Mapping:
$VNetPrefix = "10.1.0.0/16"
$SubnetPrefix = "10.1.0.0/24"
$LsIP = "10.1.0.5"

#Domain information:
$VMAdmin = "admin.ackbar"

#Port options: https://learn.microsoft.com/en-us/cli/azure/network/nsg/rule?view=azure-cli-latest#az-network-nsg-rule-create
$Ports = 22, 3389
$Priorities = 1001, 1002
$Protocols = "Tcp", "Tcp"


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

    if ($Ports.length -ne $Priorities.length) {
        Write-Output "Priorities and Ports length should be equal!"
        exit -1
    }
    if ($Ports.length -ne $Protocols.length) {
        Write-Output "Protocols and Ports length should be equal!"
        exit -1
    }

    for ($i = 0; $i -le $Ports.length - 1; $i++) {
        $port = $Ports[$i]
        $priority = $Priorities[$i]
        $protocol = $Protocols[$i]
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
if ($AllowedSourcesList.length -lt 1) {
    Write-Output "**ERROR**: Variable AllowedSources must be set (set with -AllowedSources or -s)"
    exit -1
}

if ($null -ne $AutoShutdownTime) {
    if (-not( $AutoShutdownTime -match '^([01][0-9]|2[0-3])[0-5][0-9]$')) {
        Write-Output "**ERROR** Invalid time"
        Write-Output "Enter the Auto-Shutdown time in UTC (HHMM, e.g. 2230, 0000, 1900), `n`tConvert timezone as necesary: (e.g. 05:30 pm ET -> 9:30 pm UTC -> 21:30 -> 2130)"
        exit -1
    }
}

################
# Confirmation #
################
Write-Output "Supplied configuration:`n"

Write-Output "Location: $Location"
Write-Output "Resource group: $ResourceGroup"
Write-Output "Allowed sources (IP's): $AllowedSourcesList"
Write-Output "Auto-shutdown time: $AutoShutdownTime"
Write-Output "Auto-shutdown e-mail: $AutoShutdownEmail"

if (-Not$NoPrompt) {
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
Write-Output "`nWriting $VMAdmin password to password.txt"
$VMPassword | Out-File -FilePath password.txt -Encoding UTF8



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


###########################
# Configure Auto-Shutdown #
###########################

if ($null -ne $AutoShutdownTime) {
    Set-AutoShutdown "LS1"
}

Write-Output "`nVM login info:"
Write-Output "Username: $( $VMAdmin )"
Write-Output "Password: $( $VMPassword )"
Write-Output "SAVE THE ABOVE INFO`n"

Write-Output "The time is $( Get-Date )."
Write-Output "Done."
