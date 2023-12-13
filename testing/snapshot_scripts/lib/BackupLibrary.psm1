function Get-SubscriptionId {
    # Get the current Azure subscription ID
    return az account show --query "id" -o tsv
}

function Get-VMInfo {
    param(
        [string]$vmName,
        [string]$resourceGroupName
    )

    # Get the location and storage account of the VM
    Write-Output "Getting details for ${vmName} to determine location and storage account"
    return (az vm show --name $vmName --resource-group $resourceGroupName --query "location" -o tsv).Trim()
}

function Get-ValidStorageName {
    param(
        [string]$baseName,
        [string]$version
    )

    # Function to sanitize and format the storage account name
    function Format-ForStorageName {
        param([string]$namePart)
        # Remove invalid characters, convert to lower case, and trim to max length
        return ($namePart -replace '[^a-z0-9]', '').ToLower()
    }

    # Sanitize base name and version
    $cleanBaseName = Format-ForStorageName -namePart $baseName
    $cleanVersion = Format-ForStorageName -namePart $version

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

function Create-StorageAccount {
    param(
        [string]$storageAccountName,
        [string]$resourceGroupName,
        [string]$vmLocation
    )

    az storage account create `
        --name $storageAccountName `
        --resource-group $resourceGroupName `
        --location $vmLocation `
        --sku Standard_LRS `
        --kind StorageV2
}

function Create-Vault {
    param(
        [string]$vaultName,
        [string]$resourceGroupName,
        [string]$vmLocation
    )

    az backup vault create `
        --name $vaultName `
        --resource-group $resourceGroupName `
        --location $vmLocation
}

function Get-VaultId {
    param(
        [string]$vaultName,
        [string]$resourceGroupName
    )

    return az backup vault show `
        --name $vaultName `
        --resource-group $resourceGroupName `
        --query id `
        -o tsv
}

function Write-Policy-To-File {
    param(
        [string]$policyName,
        [string]$resourceGroupName,
        [string]$vaultName,
        [string]$fileName = "policy.json"
    )

    az backup policy show `
        --name $policyName `
        --resource-group $resourceGroupName `
        --vault-name $vaultName `
        --output json > $fileName
}

function Set-BackupPolicy {
    param(
        [string]$policyName,
        [string]$resourceGroupName,
        [string]$vaultName,
        [string]$fileName = "policy.json"
    )

    az backup policy set `
        --name $policyName `
        --vault-name $vaultName `
        --resource-group $resourceGroupName `
        --policy "@$fileName"
}

function Enable-BackupProtection {
    param(
        [string]$vaultName,
        [string]$resourceGroupName,
        [string]$vmName,
        [string]$policyName
    )

    az backup protection enable-for-vm `
        --vault-name $vaultName `
        --resource-group $resourceGroupName `
        --vm $vmName `
        --policy-name $policyName
}

function Backup-Now {
    param(
        [string]$resourceGroupName,
        [string]$vaultName,
        [string]$vmName
    )

    return az backup protection backup-now `
        --resource-group $resourceGroupName `
        --vault-name $vaultName `
        --container-name $vmName `
        --item-name $vmName `
        --retain-until (Get-Date).AddDays(30).ToString("dd-MM-yyyy") `
        --backup-management-type AzureIaasVM `
        --output json
}

function Wait-ForBackupJob {
    param(
        [string]$backupJobId
    )

    do {
        Start-Sleep -Seconds 30
        $backupJobStatus = az backup job show --id $backupJobId --query "properties.status" -o tsv
        Write-Output "Waiting for backup job to complete. Current status: $backupJobStatus"
    } while ($backupJobStatus -eq "InProgress")
}

function Get-RecoveryPoints {
    param(
        [string]$containerName,
        [string]$vmName,
        [string]$resourceGroupName,
        [string]$vaultName
    )

    return az backup recoverypoint list `
        --container-name $containerName `
        --item-name $vmName `
        --resource-group $resourceGroupName `
        --vault-name $vaultName `
        --output json
}

function Restore-Disks {
    param(
        [string]$resourceGroupName,
        [string]$vaultName,
        [string]$containerName,
        [string]$vmName,
        [string]$storageAccountName,
        [string]$latestRecoveryPointName
    )

    return az backup restore restore-disks `
        --resource-group $resourceGroupName `
        --target-resource-group $resourceGroupName `
        --vault-name $vaultName `
        --storage-account $storageAccountName `
        --container-name $containerName `
        --item-name $vmName `
        --rp-name  $latestRecoveryPointName `
        --output json
}

function Wait-ForRestoreJob {
    param(
        [string]$restoreJobId
    )

    do {
        Start-Sleep -Seconds 30
        $restoreJobStatus = az backup job show --id $restoreJobId --query "properties.status" -o tsv
        Write-Output "Waiting for restore job to complete. Current status: $restoreJobStatus"
    } while ($restoreJobStatus -eq "InProgress" -or $restoreJobStatus -eq "InProgress")
}

function Get-Disks {
    param(
        [string]$resourceGroupName
    )

    return az disk list --resource-group $resourceGroupName --output json
}

function Get-RestoredDisks {
    param(
        [string]$resourceGroupName
    )

    # Get the list of disks in JSON format
    $disksJson = Get-Disks -resourceGroupName $resourceGroupName

    # Convert JSON string to PowerShell object
    $disks = $disksJson | ConvertFrom-Json

    # Filter to find disks created by a restore operation
    $restoredDisks = $disks | Where-Object { $_.creationData.createOption -eq "Restore" }

    # Sort the restored disks by their creation time and select the latest one
    $latestRestoredDisk = $restoredDisks | Sort-Object { $_.timeCreated } -Descending | Select-Object -First 1

    return $latestRestoredDisk
}

function Create-Snapshot {
    param(
        [string]$snapshotName,
        [string]$resourceGroupName,
        [string]$subscriptionId,
        [string]$diskName,
        [string]$vmLocation
    )

    az snapshot create `
        --name $snapshotName `
        --resource-group $resourceGroupName `
        --source "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/disks/$diskName" `
        --location $vmLocation
}

function Move-Snapshot {
    param(
        [string]$snapshotResourceGroupName,
        [string]$subscriptionId,
        [string]$resourceGroupName,
        [string]$snapshotName
    )

    az resource move `
        --destination-group $snapshotResourceGroupName `
        --ids "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/snapshots/$snapshotName"
}
