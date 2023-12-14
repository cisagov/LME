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

# Get the path of the current script
$scriptPath = $PSScriptRoot

# Append the backup library path
$backupLibraryPath = Join-Path -Path $scriptPath -ChildPath "lib/BackupLibrary.psm1"

# Import the BackupLibrary module
Import-Module $backupLibraryPath

# Get the current Azure subscription ID
$subscriptionId = Get-SubscriptionId

# Get the location of the VM
Write-Output "Getting details for ${vmName} to determine location and storage account"
$vmLocation = Get-VMInfo -vmName $vmName -resourceGroupName $resourceGroupName

# Construct the final snapshot resource group name
$snapshotResourceGroupName = "TestbedAssets-${vmLocation}"

$storageAccountName = Get-ValidStorageName -baseName $vmName -version $version

Write-Output "Using location ${vmLocation} and storage account ${storageAccountName}"

Write-Output "Creating the storage account for the disks"
Create-StorageAccount -storageAccountName $storageAccountName -resourceGroupName $resourceGroupName -vmLocation $vmLocation

Write-Output "Creating a Recovery Services vault in its resource group"
$vaultName = Get-ValidStorageName -baseName $vmName -version $version

Write-Output "Creating a backup vault"
Create-Vault -vaultName $vaultName -resourceGroupName $resourceGroupName -vmLocation $vmLocation

Write-Output "Getting vault details"
$vaultId = Get-VaultId -vaultName $vaultName -resourceGroupName $resourceGroupName

Write-Output "Getting default backup policy"

# Get the list of policies in JSON format
$policyName = "NewDefaultPolicy"
Write-PolicyToFile -policyName "EnhancedPolicy" -resourceGroupName $resourceGroupName -vaultName $vaultName


Write-Output "Setting default backup policy ${policyName} ${vaultName} ${resourceGroupName}"
Set-BackupPolicy -policyName $policyName -resourceGroupName $resourceGroupName -vaultName $vaultName

# Enable backup for the VM
Write-Output "Setting backup protection for ${vmName}: ${vaultName} ${resourceGroupName} ${vmName} ${policyName}"
Enable-BackupProtection -vaultName $vaultName -resourceGroupName $resourceGroupName -vmName $vmName -policyName $policyName

# Trigger the initial backup
Write-Output "Backing up ${vmName}: ${resourceGroupName} ${vaultName} ${vmName}"
$backupJobJson = Backup-Now -resourceGroupName $resourceGroupName -vaultName $vaultName -vmName $vmName

Write-Output "Backup job details: $backupJobJson"

# Convert JSON string to PowerShell object
$backupJob = $backupJobJson | ConvertFrom-Json

$backupJobId = $backupJob.Id

# Polling for the completion of the backup job
Write-Output "Waiting for backup job to complete. ${backupJobId}"
Wait-ForBackupJob -backupJobId $backupJobId

$containerName = "IaasVMContainer;$($backupJob.properties.containerName)"

# List the recovery points to find the latest one
$recoveryPointsJson = Get-RecoveryPoints `
                        -containerName $containerName `
                        -vmName $vmName `
                        -resourceGroupName $resourceGroupName `
                        -vaultName $vaultName

# Convert the JSON output to a PowerShell object for easier handling.
$recoveryPoints = $recoveryPointsJson | ConvertFrom-Json

# Sort the recovery points by their timestamp in descending order and select the first one, which is the most recent.
$latestRecoveryPoint = $recoveryPoints | Sort-Object { $_.properties.recoveryPointTime } -Descending | Select-Object -First 1

# Extract the name of the latest recovery point for use in your restore command.
$latestRecoveryPointName = $latestRecoveryPoint.name

# Restore VM to create a new managed disk
Write-Output @"
Restoring disks for ${vmName}:
 --resource-group ${resourceGroupName}
 --target-resource-group ${resourceGroupName}
 --vault-name ${vaultName}
 --storage-account ${storageAccountName}
 --container-name ${containerName}
 --item-name ${vmName}
 --rp-name ${latestRecoveryPointName}
"@

$restoreJobJson = Restore-Disks `
                    -resourceGroupName $resourceGroupName `
                    -vaultName $vaultName `
                    -containerName $containerName `
                    -vmName $vmName `
                    -storageAccountName $storageAccountName `
                    -latestRecoveryPointName $latestRecoveryPointName

# Convert JSON string to PowerShell object
$restoreJob = $restoreJobJson | ConvertFrom-Json

Write-Output "Restore job details: $restoreJob"

# Polling for the completion of the restore job
$restoreJobId = $restoreJob.Id

Wait-ForRestoreJob -restoreJobId $restoreJobId

# Get the latest restored disk
$latestRestoredDisk = Get-RestoredDisks -resourceGroupName $resourceGroupName

# Output the name of the latest restored disk
if (-not $latestRestoredDisk) {
    Write-Output "No restored disks found. The snapshot cannot be created."
    exit 1
}

Write-Output "Latest restored disk name: $( $latestRestoredDisk.name )"

# Make the diskname a variable for easier use
$diskName = $latestRestoredDisk.name

# Take a snapshot of the created disk
$snapshotName = "$vmName-$version"
Write-Output "Creating a snapshot of the restored disk so we can copy to regions"
Create-Snapshot `
    -snapshotName $snapshotName `
    -resourceGroupName $resourceGroupName `
    -subscriptionId $subscriptionId `
    -diskName $diskName `
    -vmLocation $vmLocation


# Move the snapshot to the snapshot resource group if necessary
Write-Output "Moving the snapshot to the ${snapshotResourceGroupName} resource group"
Move-Snapshot `
    -snapshotResourceGroupName $snapshotResourceGroupName `
    -subscriptionId $subscriptionId `
    -resourceGroupName $resourceGroupName `
    -snapshotName $snapshotName
