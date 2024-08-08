# PowerShell script to configure Windows Event Collector

param(
    [string]$XmlFilePath = "C:\lme\LME\Chapter 1 Files\lme_wec_config.xml"
)

# Check if Windows Event Collector Service is running and start it if not
$wecService = Get-Service -Name "Wecsvc"
if ($wecService.Status -ne 'Running') {
    Start-Service -Name "Wecsvc"
    Write-Output "Windows Event Collector Service started."
} else {
    Write-Output "Windows Event Collector Service is already running."
}

# Check if the XML configuration file exists
if (Test-Path -Path $XmlFilePath) {
    # Run the wecutil command to configure the collector
    wecutil cs $XmlFilePath
    Write-Output "wecutil command executed successfully with config file: $XmlFilePath"
} else {
    Write-Output "Configuration file not found at $XmlFilePath"
}

