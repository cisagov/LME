# Description:
# This script copies a snapshot to multiple regions.
# Run it for each of the virtual machine snapshots you create,
# so they will be available to all the regions you want to test in.
# Then copy the outputs from the script and put them into the corresponding places
# in the SetupTestbed.ps1 script.

# Usage:
# ```powershell
# .\CopySnapshotToRegions.ps1 `
#     -snapshotName "SnapshotName" `
#     -version "SnapshotVersion" `
#     -sourceResourceGroup "SourceGroup" `
# ```

param(
    [Parameter(Mandatory=$true)]
    [string]$snapshotName,
    [Parameter(Mandatory=$true)]
    [string]$version,
    [Parameter(Mandatory=$true)]
    [string]$sourceResourceGroup
)

# Get the current Azure subscription ID
$subscriptionID = az account show --query id -o tsv

# Define the array of target regions
#$targetRegions = @("centralus", "eastus", "eastus2", "southcentralus", "westus2", "westus3")
$targetRegions = @("eastus")

# Initialize hashtable
$snapshots = @{}

# Concatenate snapshot name and version
$fullSnapshotName = "$snapshotName-$version"

# Get the region and ID of the source snapshot
$sourceRegion = (az snapshot show -n $fullSnapshotName -g $sourceResourceGroup --query "location" -o tsv)
$sourceSnapshotId = (az snapshot show -n $fullSnapshotName -g $sourceResourceGroup --query "id" -o tsv)

# Store the original snapshot's information in the hashtable
if (-not $snapshots[$sourceRegion]) {
    $snapshots[$sourceRegion] = @{}
}
if (-not $snapshots[$sourceRegion][$version]) {
    $snapshots[$sourceRegion][$version] = @{}
}
$snapshots[$sourceRegion][$version][$snapshotName] = $sourceSnapshotId

foreach ($region in $targetRegions) {
    # Skip if the region is the same as the source snapshot's region
    if ($region -eq $sourceRegion) {
        continue
    }

    # Define the target resource group based on region
    $targetResourceGroup = "TestbedAssets-$region"

    # Check if the target resource group exists, create if not
    $groupExists = az group exists --name $targetResourceGroup --output tsv
    if (-not [System.Convert]::ToBoolean($groupExists)) {
        az group create --name $targetResourceGroup --location $region
        Write-Host "Created resource group $targetResourceGroup in $region."
    }

    # Generate a random string
    $randomString = -join ((48..57) + (97..122) | Get-Random -Count 4 | ForEach-Object {[char]$_})


    # Generate a unique storage account name
    $storageAccountName = "st" + $region.ToLower().Replace(" ", "") + $randomString + "acc"

    # Step 1: Create a Storage Account in the target location
    az storage account create --name $storageAccountName --resource-group $targetResourceGroup --location $region

    # Step 2: Get the Storage Key
    $storageKey = az storage account keys list --resource-group $targetResourceGroup --account-name $storageAccountName --query '[0].value' --output tsv

    # Step 3: Create a Container
    $containerName = "snapshotcont" + $randomString
    az storage container create --name $containerName --account-key $storageKey --account-name $storageAccountName

    # Step 4: Grant access to your own snapshot
    $sasDuration = "14400"
    $sas = az snapshot grant-access --resource-group $sourceResourceGroup --name $fullSnapshotName --duration-in-seconds $sasDuration --query [accessSas] --output tsv

    # Step 5: Use the SAS to copy the snapshot to the container
    $destinationBlob = $fullSnapshotName + ".vhd"
    Write-Host "Starting copy of snapshot to $region..."
    az storage blob copy start --destination-blob $destinationBlob --destination-container $containerName --account-key $storageKey --account-name $storageAccountName --source-uri $sas

    # Step 6: Wait for copy to complete
    do {
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 15
        $copyStatus = az storage blob show --name $destinationBlob --container-name $containerName --account-key $storageKey --account-name $storageAccountName --query '[properties.copy.status]' --output tsv
    } while ($copyStatus -ne 'success')

    Write-Host  # New line after dots

    # Step 7: Create snapshot in target region
    #$targetSnapshotName = $snapshotName + "_copy"
    $targetSnapshotName = $fullSnapshotName
    Write-Host "Creating the snapshot from the copy in $region..."
    az snapshot create --name $targetSnapshotName --resource-group $targetResourceGroup --location $region --source "https://${storageAccountName}.blob.core.windows.net/${containerName}/${destinationBlob}" --source-storage-account-id "/subscriptions/$subscriptionID/resourceGroups/$targetResourceGroup/providers/Microsoft.Storage/storageAccounts/$storageAccountName"

    # Retrieve the ID of the created snapshot
    $snapshotId = az snapshot show --name $targetSnapshotName --resource-group $targetResourceGroup --query id -o tsv

    # Step 8: Update hashtable
    if (-not $snapshots[$region]) {
        $snapshots[$region] = @{}
    }
    if (-not $snapshots[$region][$version]) {
        $snapshots[$region][$version] = @{}
    }
    $snapshots[$region][$version][$snapshotName] = $snapshotId

    # Step 9: Cleanup
    Write-Host "Deleting the storage account in $region..."
    az storage account delete --resource-group $targetResourceGroup --name $storageAccountName --yes
}

# Print the entire hashtable
$snapshots.GetEnumerator() | ForEach-Object {
    $region = $_.Key
    $_.Value.GetEnumerator() | ForEach-Object {
        $version = $_.Key
        $_.Value.GetEnumerator() | ForEach-Object {
            Write-Host "Region: $region, Version: $version, Name: $($_.Key), ID: $($_.Value)"
        }
    }
}
