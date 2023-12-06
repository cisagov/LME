function CreateVMFromSnapshot {
    param (
        [Parameter(Mandatory = $true)]
        [string]$NewVmName,

        [Parameter(Mandatory = $true)]
        [string]$RandomString,

        [Parameter(Mandatory = $true)]
        [string]$OsType,

        [Parameter(Mandatory = $true)]
        [string]$VmSize,

        [Parameter(Mandatory = $true)]
        [string]$Version,

        [Parameter(Mandatory = $true)]
        [string]$ResourceGroup,

        [Parameter(Mandatory = $true)]
        [string]$Location,

        [Parameter(Mandatory = $true)]
        [string]$Nsg,

        [Parameter(Mandatory = $true)]
        [string]$VNetName,

        [Parameter(Mandatory = $true)]
        [string]$Subnet,

        [Parameter(Mandatory = $false)]
        [string]$IP = $null
    )
    $CapOsType = $OsType.Substring(0, 1).ToUpper() + $OsType.Substring(1).ToLower()

    $NewDiskName = "${NewVmName}_OsDisk_1_${RandomString}"
    Write-Output "`nRestoring $NewVmName..."

    Write-Host "Using snapshot id: $snapshotId"
    Write-Host "Creating $NewDiskName in $ResourceGroup"

    Write-Host "Creating vm $NewVmName in $ResourceGroup using ip $IP"
    # Start constructing the command
    $vmCreateCommand = "az vm create " +
            "--resource-group $ResourceGroup " +
            "--name $NewVmName " +
            "--nsg $Nsg " +
            "--attach-os-disk $NewDiskName " +
            "--os-type $OsType " +
            "--size $VmSize " +
            "--location $Location " +
            "--vnet-name $VNetName " +
            "--subnet $Subnet " +
            "--public-ip-sku Standard"

    # Add the private IP address argument only if $IP is not null
    if ([string]::IsNullOrWhiteSpace($IP) -eq $false) {
        $vmCreateCommand += " --private-ip-address $IP"
        Write-Host "Using IP: $IP"
    }
    else {
        Write-Host "No private IP address specified"
    }
}


CreateVMFromSnapshot `
    -NewVmName "C1" `
    -RandomString "blabla" `
    -OsType "windows" `
    -VmSize "Standard_DS1_v2" `
    -Version "1.1.0" `
    -ResourceGroup "mygroup" `
    -Location "Location" `
    -Nsg "NSG1" `
    -VNetName "Vmnet1" `
    -Subnet "Subnet" `
    -IP "192.168.1.1"



