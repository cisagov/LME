param(
    [Parameter(Mandatory = $true)]
    [Alias("n")]
    [string]$vmName,

    [Parameter(Mandatory = $true)]
    [Alias("v")]
    [string]$version,

    [Parameter(Mandatory = $true)]
    [Alias("g")]
    [string]$resourceGroupName
)

# Get the current Azure subscription ID
$subscriptionId = az account show --query "id" -o tsv

# Construct the vault name based on the VM name and version
$vaultName = "$vmName-$version-"

# Calculate the remaining characters needed to reach the maximum length
$remainingChars = 24 - $vaultName.Length

# If the vault name is less than the maximum length, append random characters
Write-Output "Generating random characters to create a new vault name"
if ($remainingChars -gt 0) {
    # Generate a random string of the remaining length
    $randomString = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count $remainingChars | ForEach-Object { [char]$_ })

    # Append the random string to the vault name
    $vaultName += $randomString
}

# Get the location and storage account of the VM
Write-Output "Getting details for ${vmName} to determine location and storage account"
$vmLocation = (az vm show --name $vmName --resource-group $resourceGroupName --query "location" -o tsv).Trim()

$storageAccountName = "${vmName}-${version}-sa"
az storage account create `
    --name $storageAccountName `
    --resource-group $resourceGroupName `
    --location $vmLocation `
    --sku Standard_LRS `
    --kind StorageV2

Write-Output "Using location ${vmLocation} and storage account ${storageAccountName}"

# Construct the snapshot resource group name
$snapshotResourceGroupName = "TestbedAssets-${vmLocation}"

# Create a Recovery Services vault in its resource group
Write-Output "Creating a backup vault"
az backup vault create `
    --name $vaultName `
    --resource-group $resourceGroupName `
    --location $vmLocation

# Get vault details
Write-Output "Getting vault details"
$vaultId = az backup vault show `
    --name $vaultName `
    --resource-group $resourceGroupName `
    --query id `
    -o tsv

# Set backup policy
Write-Output "Setting default backup policy"
$policyName = "DefaultPolicy"
az backup policy set `
    --name $policyName `
    --vault-name $vaultName `
    --resource-group $resourceGroupName `
    --policy (az backup policy list ` --resource-group $resourceGroupName ` --vault-name $vaultName ` --query "[?properties.datasourceType=='AzureIaasVM'].name" --output json)

# Enable backup for the VM
Write-Output "Setting backup protection for ${vmName}"
az backup protection enable-for-vm `
    --vault-name $vaultName `
    --resource-group $resourceGroupName `
    --vm $vmName `
    --vm-resource-group $resourceGroupName `
    --policy-name $policyName

# Trigger the initial backup
Write-Output "Backing up ${vmName}"
$backupJob = az backup protection backup-now `
    --resource-group $resourceGroupName `
    --vault-name $vaultName `
    --container-name $vmName `
    --item-name $vmName `
    --retain-until (Get-Date).AddDays(30).ToString("yyyy-MM-dd") `
    --backup-management-type AzureIaasVM


$recoveryPointName = $backupJob.properties.entityFriendlyName

# Polling for the completion of the backup job
$backupJobId = $backupJob.Id
do {
    Start-Sleep -Seconds 30
    $backupJobStatus = az backup job show --id $backupJobId --query "properties.status" -o tsv
    Write-Output "Waiting for backup job to complete. Current status: $backupJobStatus"
} while ($backupJobStatus -eq "InProgress" -or $backupJobStatus -eq "InProgress")


$diskName = "$vmName-$version-disk"

# Restore VM to create a new managed disk
Write-Output "Restoring disks for ${vmName}"
$restoreJob = az backup restore restore-disks `
    --resource-group $resourceGroupName `
    --vault-name $vaultName `
    --container-name $vmName `
    --item-name $vmName `
    --storage-account $storageAccountName `
    --rp-name $recoveryPointName `
    --target-resource-group $resourceGroupName `
    --disk-name $diskName

# Polling for the completion of the restore job
$restoreJobId = $restoreJob.Id
do {
    Start-Sleep -Seconds 30
    $restoreJobStatus = az backup job show --id $restoreJobId --query "properties.status" -o tsv
    Write-Output "Waiting for restore job to complete. Current status: $restoreJobStatus"
} while ($restoreJobStatus -eq "InProgress" -or $restoreJobStatus -eq "InProgress")

# Take a snapshot of the created disk
$snapshotName = "$vmName-$version"
Write-Output "Creating a snapshot of the restored disk so we can copy to regions"
az snapshot create `
    --name $snapshotName `
    --resource-group `
    $resourceGroupName `
    --source "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/disks/$diskName" `
    --location $vmLocation

# Move the snapshot to the snapshot resource group if necessary
Write-Output "Moving the snapshot to the ${snapshotResourceGroupName} resource group"
az resource move `
    --destination-group $snapshotResourceGroupName `
    --ids "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/snapshots/$snapshotName"
