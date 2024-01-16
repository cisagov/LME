<#
.SYNOPSIS
This script sets and retrieves a Group Policy (GP) registry value for Windows Event Log Event Forwarding.

.DESCRIPTION
The script is used to configure the Subscription Manager URL for Windows Event Log Event Forwarding in a Group Policy setting. It sets the registry value for the Subscription Manager URL using the specified domain, port, and protocol, and then retrieves the value to confirm the setting. This is useful in environments where centralized event log management is required.

.PARAMETER domain
The domain for the Subscription Manager URL. Default is 'dc1.lme.local'.

.PARAMETER port
The port number for the Subscription Manager URL. Default is 5985.

.PARAMETER protocol
The protocol for the Subscription Manager URL. Default is 'http'.

.EXAMPLE
.\wec_gpo_update_server_name.ps1
Executes the script with default parameters.

.EXAMPLE
.\wec_gpo_update_server_name.ps1 -Domain "customdomain.local" -Port 1234 -Protocol "https"
Executes the script with custom domain, port, and protocol.

#>

param(
    [string]$Domain = "dc1.lme.local",
    [int]$Port = 5985,
    [string]$Protocol = "http"
)

# Construct the Subscription Manager URL using the provided parameters
$subscriptionManagerUrl = "Server=${Protocol}://${Domain}:${Port}/wsman/SubscriptionManager/WEC,Refresh=60"
Set-GPRegistryValue -Name "LME-WEC-Client" -Key "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\EventLog\EventForwarding\SubscriptionManager" -Value $subscriptionManagerUrl -Type String

# To get the GP registry value to confirm it's set
$registryValue = Get-GPRegistryValue -Name "LME-WEC-Client" -Key "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\EventLog\EventForwarding\SubscriptionManager"

# Output the retrieved registry value
Write-Output "Set the subscription manager url value to: "
$registryValue
