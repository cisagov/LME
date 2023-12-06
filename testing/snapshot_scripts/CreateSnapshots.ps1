# Description: Creates snapshots of the VMs in the specified resource group

# .\CreateSnapshots.ps1 `
#    -resourceGroup "MyResourceGroup" `
#    -versionSuffix "1.1.0" `
#    -targetResourceGroup "TestbedAssets-regioncode"

param(
    [Parameter(Mandatory=$true)]
    [Alias("r")]
    [string]$resourceGroup,

    [Parameter(Mandatory=$true)]
    [Alias("s")]
    [string]$versionSuffix,

    [Parameter(Mandatory=$true)]
    [Alias("t")]
    [string]$targetResourceGroup
)

$vmNames = @("DC1", "C1", "C2", "LS1")

foreach ($vmName in $vmNames) {
    $snapshotName = "$vmName-$versionSuffix"

    # Get the Disk ID of the VM's OS Disk
    $diskId = & az vm show --resource-group $resourceGroup --name $vmName --query "storageProfile.osDisk.managedDisk.id" -o tsv
    # Write-Host "Disk ID for ${vmName}: $diskId"

    # Create a Snapshot of the Disk
    az snapshot create --resource-group $targetResourceGroup --name $snapshotName --source $diskId --sku Standard_LRS
    Write-Host "Snapshot created for ${vmName}: $snapshotName"
}