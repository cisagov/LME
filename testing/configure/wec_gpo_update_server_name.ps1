# To set the GP registry value
Set-GPRegistryValue -Name "LME-WEC-Client" -Key "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\EventLog\EventForwarding\SubscriptionManager" -Value "Server=https://dc1.lme.local:5986/wsman/SubscriptionManager/WEC,Refresh=60" -Type String

# To get the GP registry value to confirm it's set
$registryValue = Get-GPRegistryValue -Name "LME-WEC-Client" -Key "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\EventLog\EventForwarding\SubscriptionManager"

# Output the retrieved registry value
Write-Host "Set the subscription manager url value to: "
$registryValue