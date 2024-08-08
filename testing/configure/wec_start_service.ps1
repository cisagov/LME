# Start WEC using custom wec xml file

try {
    Start-Service -Name "Wecsvc"
    Write-Output "WEC service started successfully."
} catch {
    Write-Output "Failed to start WEC service: $_"
}

$ConfigFilePath = "$env:USERPROFILE\Downloads\LME\Chapter 1 Files\lme_wec_config.xml"

try {
    Start-Process -FilePath "wecutil.exe" -ArgumentList "cs `"$ConfigFilePath`"" -Verb RunAs
    Write-Output "wecutil command executed successfully."
} catch {
    Write-Output "Failed to execute wecutil command: $_"
}


