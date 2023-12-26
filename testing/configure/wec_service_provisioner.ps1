# PowerShell script to configure Windows Event Collector

param(
    [string]$xmlFilePath = "C:\lme\LME\Chapter 1 Files\lme_wec_config.xml"
)

# Check if Windows Event Collector Service is running and start it if not
$wecService = Get-Service -Name "Wecsvc"
if ($wecService.Status -ne 'Running') {
    Start-Service -Name "Wecsvc"
    Write-Host "Windows Event Collector Service started."
} else {
    Write-Host "Windows Event Collector Service is already running."
}

# Check if the XML configuration file exists
if (Test-Path -Path $xmlFilePath) {
    # Run the wecutil command to configure the collector
    wecutil cs $xmlFilePath
    Write-Host "wecutil command executed successfully with config file: $xmlFilePath"
} else {
    Write-Host "Configuration file not found at $xmlFilePath"
}

