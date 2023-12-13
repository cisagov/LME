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

function Get-ValidStorageName {
    param(
        [string]$baseName,
        [string]$version
    )

    # Function to sanitize and format the storage account name
    function Sanitize-ForStorageName {
        param([string]$namePart)
        # Remove invalid characters, convert to lower case, and trim to max length
        return ($namePart -replace '[^a-z0-9]', '').ToLower()
    }

    # Sanitize base name and version
    $cleanBaseName = Sanitize-ForStorageName -namePart $baseName
    $cleanVersion = Sanitize-ForStorageName -namePart $version

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

$storageAccountName = Get-ValidStorageName -baseName $vmName -version $version

Write-Output "Using location ${vmLocation} and storage account ${storageAccountName}"

Write-Output "Creating the storage account for the disks"
az storage account create `
    --name $storageAccountName `
    --resource-group $resourceGroupName `
    --location $vmLocation `
    --sku Standard_LRS `
    --kind StorageV2

# Create a Recovery Services vault in its resource group
$vaultName = Get-ValidStorageName -baseName $vmName -version $version
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
Write-Output "Backup job details: $backupJobJson"

# Polling for the completion of the backup job
$backupJobId = $backupJob.Id
Write-Output "Waiting for backup job to complete. ${backupJobId}"
do {
    Start-Sleep -Seconds 30
    $backupJobStatus = az backup job show --id $backupJobId --query "properties.status" -o tsv
    Write-Output "Waiting for backup job to complete. Current status: $backupJobStatus"
} while ($backupJobStatus -eq "InProgress")

$containerName = "IaasVMContainer;$($backupJob.properties.containerName)"

# List the recovery points to find the latest one
$recoveryPointsJson = az backup recoverypoint list `
    --container-name $containerName `
    --item-name $vmName `
    --resource-group $resourceGroupName `
    --vault-name $vaultName `
    --output json

#Convert JSON to PowerShell Object: Convert the JSON output to a PowerShell object for easier handling.
$recoveryPoints = $recoveryPointsJson | ConvertFrom-Json

#Sort and Select the Latest Recovery Point: Sort the recovery points by their timestamp in descending order and select the first one, which is the most recent.
$latestRecoveryPoint = $recoveryPoints | Sort-Object { $_.properties.recoveryPointTime } -Descending | Select-Object -First 1

#Extract the Recovery Point Name: Extract the name of the latest recovery point for use in your restore command.
$latestRecoveryPointName = $latestRecoveryPoint.name

# Restore VM to create a new managed disk
Write-Output "Restoring disks for ${vmName}:"
Write-Output " --resource-group ${resourceGroupName}"
Write-Output " --target-resource-group ${resourceGroupName}"
Write-Output " --vault-name ${vaultName}"
Write-Output " --storage-account ${storageAccountName}"
Write-Output " --container-name ${containerName}"
Write-Output " --item-name ${vmName}"
Write-Output "--rp-name ${latestRecoveryPointName}"

$restoreJobJson = az backup restore restore-disks `
    --resource-group $resourceGroupName `
    --target-resource-group $resourceGroupName `
    --vault-name $vaultName `
    --storage-account $storageAccountName `
    --container-name $containerName `
    --item-name $vmName `
    --rp-name  $latestRecoveryPointName `
    --output json

# Convert JSON string to PowerShell object
$restoreJob = $restoreJobJson | ConvertFrom-Json

Write-Output "Restore job details: $restoreJob"

# Polling for the completion of the restore job
$restoreJobId = $restoreJob.Id
do {
    Start-Sleep -Seconds 30
    $restoreJobStatus = az backup job show --id $restoreJobId --query "properties.status" -o tsv
    Write-Output "Waiting for restore job to complete. Current status: $restoreJobStatus"
} while ($restoreJobStatus -eq "InProgress" -or $restoreJobStatus -eq "InProgress")

# Get the list of disks in JSON format
$disksJson = az disk list --resource-group $resourceGroupName --output json

# Convert JSON string to PowerShell object
$disks = $disksJson | ConvertFrom-Json

# Filter to find disks created by a restore operation
$restoredDisks = $disks | Where-Object { $_.creationData.createOption -eq "Restore" }

# Sort the restored disks by their creation time and select the latest one
$latestRestoredDisk = $restoredDisks | Sort-Object { $_.timeCreated } -Descending | Select-Object -First 1

# Output the name of the latest restored disk
if ($latestRestoredDisk) {
    Write-Output "Latest restored disk name: $( $latestRestoredDisk.name )"
}
else {
    Write-Output "No restored disks found."
}

# Make the diskname a variable for easier use
$diskName = $latestRestoredDisk.name

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
