# Start WEC using custom wec xml file

try {
    Start-Service -Name "Wecsvc"
    Write-Host "WEC service started successfully."
} catch {
    Write-Host "Failed to start WEC service: $_"
}

$ConfigFilePath = "$env:USERPROFILE\Downloads\LME\Chapter 1 Files\lme_wec_config.xml"

try {
    Start-Process -FilePath "wecutil.exe" -ArgumentList "cs `"$ConfigFilePath`"" -Verb RunAs
    Write-Host "wecutil command executed successfully."
} catch {
    Write-Host "Failed to execute wecutil command: $_"
}


