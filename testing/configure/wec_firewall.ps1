# Asks user to provide subnet - then creates a inbound allow firewall rule for 5985. Run on WEC server.
param (
    [string]$InboundRuleName = "WinRM TCP In 5985",
    [string]$ClientSubnet = "10.1.0.0/24",
    [string]$LocalPort = "5985"
)

if (-not (Get-NetFirewallRule -Name $InboundRuleName -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName $InboundRuleName `
                        -Direction Inbound -Protocol TCP `
                        -LocalPort $LocalPort -Action Allow `
                        -RemoteAddress $ClientSubnet `
                        -Description "Allow inbound TCP ${LocalPort} for WinRM from clients subnet"
} else {
    Write-Output "Inbound rule '$InboundRuleName' already exists."
}

Write-Output "Inbound WinRM rule has been configured."
