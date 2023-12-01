
 # Description: 
 # This script copies a snapshot to multiple regions.  
 # You will want to run it for each of the virtual machine snapshots you create. 
 # So they will be available to all the regions you want to test in.
 # Then copy the outputs from the script and put them into the corresponding places 
 # in the SetupTestbed.ps1 script.

# Usage:
# ```powershell
# .\CopySnapshotToRegions.ps1 `
#     -snapshotName "SnapshotName" `
#     -sourceResourceGroup "SourceGroup" `
#     -targetResourceGroup "TargetGroup"
# ```

param(
    [Parameter(Mandatory=$true)]
    [string]$snapshotName,
    [Parameter(Mandatory=$true)]
    [string]$sourceResourceGroup,
    [Parameter(Mandatory=$true)]
    [string]$targetResourceGroup
)

# Get the current Azure subscription ID
$subscriptionID = az account show --query id -o tsv

# Define the array of target regions
#$targetRegions = @("centralus", "eastus", "eastus2", "southcentralus", "westus2", "westus3")
$targetRegions = @("eastus")

# Initialize hashtable
$snapshots = @{}

 # Get the region of the source snapshot
$sourceRegion = (az snapshot show -n $snapshotName -g $sourceResourceGroup --query "location" -o tsv)


foreach ($region in $targetRegions) {
    # Skip if the region is the same as the source snapshot's region
    if ($region -eq $sourceRegion) {
        continue
    }

    # Generate a random string
    $randomString = -join ((65..90) + (97..122) | Get-Random -Count 4 | ForEach-Object {[char]$_})

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
    $sas = az snapshot grant-access --resource-group $sourceResourceGroup --name $snapshotName --duration-in-seconds $sasDuration --query [accessSas] --output tsv

    # Step 5: Use the SAS to copy the snapshot to the container
    $destinationBlob = $snapshotName + ".vhd"
    Write-Host "Starting copy of snapshot to $region..."
    az storage blob copy start --destination-blob $destinationBlob --destination-container $containerName --account-key $storageKey --account-name $storageAccountName --source-uri $sas

    # Step 6: Wait for copy to complete
    do {
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 15
        $copyStatus = az storage blob show --name $destinationBlob --container-name $containerName --account-key $storageKey --account-name $storageAccountName --query '[properties.copy.status]' --output tsv
    } while ($copyStatus -ne 'success')

    # Add a newline to the terminal
    Write-Host

    # Step 7: Create snapshot in target region
    # Todo: Check if we can keep the _copy off of there 
    $targetSnapshotName = $snapshotName + "_copy"
    Write-Host "Creating the snapshot from the copy in $region..."
    az snapshot create --name $targetSnapshotName --resource-group $targetResourceGroup --location $region --source "https://${storageAccountName}.blob.core.windows.net/${containerName}/${destinationBlob}" --source-storage-account-id "/subscriptions/$subscriptionID/resourceGroups/$targetResourceGroup/providers/Microsoft.Storage/storageAccounts/$storageAccountName"

    # Add to hashtable
    $snapshots[$region] = $targetSnapshotName

    # Step 9: Cleanup
    Write-Host "Deleting the storage account in $region..."
    az storage account delete --resource-group $targetResourceGroup --name $storageAccountName --yes
}

# Print the entire hashtable
$snapshots.GetEnumerator() | ForEach-Object { Write-Host "$($_.Key): $($_.Value)" }

