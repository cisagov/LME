# Description: This script will create a new VM from a snapshot.  
# It is designed to test the snapshot restore process so that we can incorporate it into the create script.
# It will create a new managed disk from the snapshot and then create a new VM using the new disk.

# Example:
# .\CreateVmFromSnapshot.ps1 `
#    -snapshotName "DC1-1.1.0" `
#    -snapshotResourceGroup "TestbedAssets" `
#    -resourceGroup "LME-cbaxley-t4" `
#    -newDiskName "DC1" `
#    -newVMName "DC1" `
#    -vmSize "Standard_DS1_v2" `
#    -location "centralus" `
#    -osType "windows" `
#    -nsg "NSG1" `
#    -DcIP "10.1.0.10" `
#    -vNetName "VNet1"

param(
    [string]$snapshotName = "DC1-1.1.0",
    [string]$snapshotResourceGroup = "LME-cbaxley-t4",
    [string]$resourceGroup = "LME-cbaxley-t4",
    [string]$newDiskName = "DC1",
    [string]$newVMName = "DC1",
    [string]$vmSize = "Standard_DS1_v2",
    [string]$location = "centralus",
    [string]$osType = "windows",
    [string]$nsg = "NSG1",
    [string]$DcIP = "10.1.0.10", 
    [string]$vNetName = "VNet1"
)

# Create a new managed disk from the snapshot
$snapshotId = (az snapshot show --name $snapshotName --resource-group $snapshotResourceGroup --query "id" -o tsv)
Write-Host "Using snapshot id: $snapshotId"
Write-Host "Creating $newDiskName in $resourceGroup"

az disk create --resource-group $resourceGroup --name $newDiskName --source $snapshotId

Write-Host "Creating vm $newVMName in $resourceGroup using ip $DcIP"
# Create a new VM using the new disk
az vm create `
        --resource-group $resourceGroup `
        --name $newVMName `
        --nsg $nsg `
        --attach-os-disk $newDiskName `
        --os-type $osType `
        --size $vmSize `
        --location $location `
        --vnet-name $vNetName `
        --subnet SNet1 `
        --public-ip-sku Standard `
        --private-ip-address $DcIP