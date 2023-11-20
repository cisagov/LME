## Sysinternals Sysmon64.exe Uninstaller
# Check if Sysmon is installed
if (Test-Path "C:\Windows\Sysmon64.exe") {
    try {
        # Perform automated uninstall with elevated privileges
        Start-Process "C:\Windows\Sysmon64.exe" -ArgumentList "-u" -Verb RunAs -Wait

        # Housekeep remaining file
        Remove-Item "C:\Windows\Sysmon64.exe" -Force
        Write-Output "Sysmon uninstalled and removed successfully."
    } catch {
        Write-Error "Error occurred during Sysmon uninstallation: $_"
    }
} else {
    Write-Warning "Sysmon is not installed."
}
