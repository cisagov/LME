# Query the registry to find the key path
$HKEY_USERSKeys = reg query HKEY_USERS /s /f "SubscriptionManager" /k

# Extract the first key path that contains "EventForwarding"
$HKEY_USERSKeyPath = ($HKEY_USERSKeys -split "\r\n" | Where-Object { $_ -match "HKEY_USERS\\.*EventForwarding" }) -replace "HKEY_USERS\\", "HKU\" | Select-Object -First 1

# Ensure the key path is not null or empty
if (-not [string]::IsNullOrWhiteSpace($HKEY_USERSKeyPath)) {
    # Display the current value
    $oldValue = reg query "$HKEY_USERSKeyPath" /v "1"
    Write-Host "Old Value: $oldValue"

    # Change the SubscriptionManager key value
    $newData = "Server=http://dc1.lme.local:5985/wsman/SubscriptionManager/WEC,Refresh=60"
    reg add "$HKEY_USERSKeyPath" /v "1" /t REG_SZ /d "$newData" /f

    # Requery to confirm the change
    $newValue = reg query "$HKEY_USERSKeyPath" /v "1"
    Write-Host "New Value: $newValue"
} else {
    Write-Host "Registry key path not found."
}