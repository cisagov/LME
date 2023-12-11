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
if ($remainingChars -gt 0) {
    # Generate a random string of the remaining length
    $randomString = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count $remainingChars | ForEach-Object { [char]$_ })

    # Append the random string to the vault name
    $vaultName += $randomString
}

# Get the location and storage account of the VM
$vmDetails = az vm show `
    --name $vmName `
    --resource-group $resourceGroupName `
    --query "{location: location, storageAccount: storageProfile.osDisk.managedDisk.storageAccountType}" `
    -o tsv

$vmLocation = $vmDetails[0]
$storageAccountName = $vmDetails[1]

# Construct the snapshot resource group name
$snapshotResourceGroupName = "TestbedAssets-${vmLocation}"

# Create a Recovery Services vault in its resource group
az backup vault create `
    --name $vaultName `
    --resource-group $resourceGroupName `
    --location $vmLocation

# Get vault details
$vaultId = az backup vault show `
    --name $vaultName `
    --resource-group $resourceGroupName `
    --query id `
    -o tsv

# Set backup policy
$policyName = "DefaultPolicy"
az backup policy set `
    --name $policyName `
    --vault-name $vaultName `
    --resource-group $resourceGroupName `
    --policy (az backup policy list ` --resource-group $resourceGroupName ` --vault-name $vaultName ` --query "[?properties.datasourceType=='AzureIaasVM'].name" --output json)

# Enable backup for the VM
az backup protection enable-for-vm `
    --vault-name $vaultName `
    --resource-group $resourceGroupName `
    --vm $vmName `
    --vm-resource-group $resourceGroupName `
    --policy-name $policyName

# Trigger the initial backup
$backupJob = az backup protection backup-now `
    --resource-group $resourceGroupName `
    --vault-name $vaultName `
    --container-name $vmName `
    --item-name $vmName `
    --retain-until (Get-Date).AddDays(30).ToString("yyyy-MM-dd") `
    --backup-management-type AzureIaasVM

$recoveryPointName = $backupJob.properties.entityFriendlyName

$diskName = "$vmName-$version-disk"

# Restore VM to create a new managed disk
az backup restore restore-disks `
    --resource-group $resourceGroupName `
    --vault-name $vaultName `
    --container-name $vmName `
    --item-name $vmName `
    --storage-account $storageAccountName `
    --rp-name $recoveryPointName `
    --target-resource-group $resourceGroupName `
    --disk-name $diskName

# Take a snapshot of the created disk
$snapshotName = "$vmName-$version"
az snapshot create `
    --name $snapshotName `
    --resource-group `
    $resourceGroupName `
    --source "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/disks/$diskName" `
    --location $vmLocation

# Move the snapshot to the snapshot resource group if necessary
az resource move `
    --destination-group $snapshotResourceGroupName `
    --ids "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/snapshots/$snapshotName"
