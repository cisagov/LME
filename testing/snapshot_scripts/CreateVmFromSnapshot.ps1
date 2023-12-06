# Description: This script will create a new VM from a snapshot.  
# It is designed to test the snapshot restore process so that we can incorporate it into the create script.
# It will create a new managed disk from the snapshot and then create a new VM using the new disk.

# Example:
# .\CreateVmFromSnapshot.ps1 `
#    -SnapshotName "DC1-1.1.0" `
#    -SnapshotResourceGroup "TestbedAssets" `
#    -ResourceGroup "LME-cbaxley-t4" `
#    -NewDiskName "DC1" `
#    -NewVMName "DC1" `
#    -VmSize "Standard_DS1_v2" `
#    -Location "centralus" `
#    -OsType "windows" `
#    -Nsg "NSG1" `
#    -DcIP "10.1.0.10" `
#    -VNetName "VNet1"

param(
    [string]$SnapshotName = "DC1-1.1.0",
    [string]$SnapshotResourceGroup = "LME-cbaxley-t4",
    [string]$ResourceGroup = "LME-cbaxley-t4",
    [string]$NewDiskName = "DC1",
    [string]$NewVMName = "DC1",
    [string]$VmSize = "Standard_DS1_v2",
    [string]$Location = "centralus",
    [string]$OsType = "windows",
    [string]$Nsg = "NSG1",
    [string]$DcIP = "10.1.0.10", 
    [string]$vNetName = "VNet1"
)

# Create a new managed disk from the snapshot
$snapshotId = (az snapshot show --name $SnapshotName --resource-group $SnapshotResourceGroup --query "id" -o tsv)
Write-Host "Using snapshot id: $snapshotId"
Write-Host "Creating $NewDiskName in $ResourceGroup"

az disk create --resource-group $ResourceGroup --name $NewDiskName --source $snapshotId

Write-Host "Creating vm $NewVMName in $ResourceGroup using ip $DcIP"
# Create a new VM using the new disk
az vm create `
        --resource-group $ResourceGroup `
        --name $NewVMName `
        --nsg $Nsg `
        --attach-os-disk $NewDiskName `
        --os-type $OsType `
        --size $VmSize `
        --location $Location `
        --vnet-name $vNetName `
        --subnet SNet1 `
        --public-ip-sku Standard `
        --private-ip-address $DcIP