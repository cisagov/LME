## Sysinternals Sysmon64.exe Uninstaller
# Perform automated uninstall
& C:\Windows\Sysmon64.exe -u
# House keep remaining file
Remove-Item C:\Windows\Sysmon64.exe