# Query the registry to find the key path
#$HKEY_USERSKeys = reg query HKEY_USERS /s /f "SubscriptionManager" /k

HKEY_USERS\S-1-5-21-1874110181-726158762-2826089689-500\Software\Microsoft\Windows\CurrentVersion\Group Policy Objects\LME.LOCAL{083A2CE3-3021-4F4D-9765-35EB888E62CF}Machine\Software\Policies\Microsoft\Windows\EventLog\Event
Forwarding\SubscriptionManager
# To set the GP registry value
Set-GPRegistryValue -Name "LME-WEC-Client" -Key "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\EventLog\EventForwarding\SubscriptionManager" -Value "Server=http://dc1.lme.local:5985/wsman/SubscriptionManager/WEC,Refresh=60" -Type String

# To get the GP registry value to confirm it's set
$registryValue = Get-GPRegistryValue -Name "LME-WEC-Client" -Key "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\EventLog\EventForwarding\SubscriptionManager"

# Output the retrieved registry value
Write-Host "Set the subscription manager url value to: "
$registryValue
