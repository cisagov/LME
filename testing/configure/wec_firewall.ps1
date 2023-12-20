# Asks user to provide subnet - then creates a inbound allow firewall rule for 5985. Run on WEC server.

$inboundRuleName = "WinRM TCP In 5985"
$clientSubnet = Read-Host "Enter your subnet (e.g., 10.1.0.0/24)"

if (-not (Get-NetFirewallRule -Name $inboundRuleName -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName $inboundRuleName `
                        -Direction Inbound -Protocol TCP `
                        -LocalPort 5985 -Action Allow `
                        -RemoteAddress $clientSubnet `
                        -Description "Allow inbound TCP 5985 for WinRM from clients subnet"
} else {
    Write-Host "Inbound rule '$inboundRuleName' already exists."
}

Write-Host "Inbound WinRM rule has been configured."
