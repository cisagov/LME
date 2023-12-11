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

# Stop the script if something goes wrong.
$ErrorActionPreference = 'Stop'

# Get the current Azure subscription ID
$subscriptionId = az account show --query "id" -o tsv


# Get the location and storage account of the VM
Write-Output "Getting details for ${vmName} to determine location and storage account"
$vmLocation = (az vm show --name $vmName --resource-group $resourceGroupName --query "location" -o tsv).Trim()

# Construct the final snapshot resource group name
$snapshotResourceGroupName = "TestbedAssets-${vmLocation}"

function Get-ValidStorageAccountName {
    param(
        [string]$baseName,
        [string]$version
    )

    # Function to sanitize and format the storage account name
    function Sanitize-ForStorageAccount {
        param([string]$namePart)
        # Remove invalid characters, convert to lower case, and trim to max length
        return ($namePart -replace '[^a-z0-9]', '').ToLower()
    }

    # Sanitize base name and version
    $cleanBaseName = Sanitize-ForStorageAccount -namePart $baseName
    $cleanVersion = Sanitize-ForStorageAccount -namePart $version

    # Start constructing the storage account name
    $storageAccountName = $cleanBaseName + $cleanVersion

    # If the name is shorter than the minimum length, append random characters
    if ($storageAccountName.Length -lt 24) {
        $randomCharsNeeded = 24 - $storageAccountName.Length
        $randomString = -join ((48..57) + (97..122) | Get-Random -Count $randomCharsNeeded | ForEach-Object { [char]$_ })
        $storageAccountName += $randomString
    }

    # Ensure the storage account name is not longer than the maximum length
    if ($storageAccountName.Length -gt 24) {
        $storageAccountName = $storageAccountName.Substring(0, 24)
    }

    return $storageAccountName
}

$storageAccountName = Get-ValidStorageAccountName -baseName $vmName -version $version

Write-Output "Using location ${vmLocation} and storage account ${storageAccountName}"

Write-Output "Creating the storage account for the disks"
az storage account create `
    --name $storageAccountName `
    --resource-group $resourceGroupName `
    --location $vmLocation `
    --sku Standard_LRS `
    --kind StorageV2



# Create a Recovery Services vault in its resource group
$vaultName = Get-ValidStorageAccountName -baseName $vmName -version $version
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
Write-Output "Getting default backup policy"

# Get the list of policies in JSON format
$policyName = "NewDefaultPolicy"
$jsonPolicy = az backup policy show `
                --name "EnhancedPolicy" `
                --resource-group $resourceGroupName `
                --vault-name $vaultName `
                --output json > policy.json

Write-Output "Setting default backup policy ${policyName} ${vaultName} ${resourceGroupName}"
az backup policy set `
    --name $policyName `
    --vault-name $vaultName `
    --resource-group $resourceGroupName `
    --policy "@policy.json"



# Enable backup for the VM
Write-Output "Setting backup protection for ${vmName}: ${vaultName} ${resourceGroupName} ${vmName} ${policyName}"
az backup protection enable-for-vm `
    --vault-name $vaultName `
    --resource-group $resourceGroupName `
    --vm $vmName `
    --policy-name $policyName


# Trigger the initial backup
Write-Output "Backing up ${vmName}: ${resourceGroupName} ${vaultName} ${vmName}"
$backupJobJson = az backup protection backup-now `
    --resource-group $resourceGroupName `
    --vault-name $vaultName `
    --container-name $vmName `
    --item-name $vmName `
    --retain-until (Get-Date).AddDays(30).ToString("dd-MM-yyyy") `
    --backup-management-type AzureIaasVM `
    --output json

# Convert JSON string to PowerShell object
$backupJob = $backupJobJson | ConvertFrom-Json

$recoveryPointName = $backupJob.properties.entityFriendlyName

# Polling for the completion of the backup job
$backupJobId = $backupJob.Id
Write-Output "Waiting for backup job to complete. ${backupJobId}"
do {
    Start-Sleep -Seconds 30
    $backupJobStatus = az backup job show --id $backupJobId --query "properties.status" -o tsv
    Write-Output "Waiting for backup job to complete. Current status: $backupJobStatus"
} while ($backupJobStatus -eq "InProgress" -or $backupJobStatus -eq "InProgress")


$diskName = "$vmName-$version-disk"

# Restore VM to create a new managed disk
Write-Output "Restoring disks for ${vmName}: ${resourceGroupName} ${vaultName} ${vmName} ${recoveryPointName} ${storageAccountName} ${diskName}"
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
