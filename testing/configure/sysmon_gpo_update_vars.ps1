param(
    [string]$gpoName = "LME-Sysmon-Task",
    [string]$domainName = "lme.local"
)

# Get the FQDN of the current server
$fqdn = [System.Net.Dns]::GetHostByName($env:COMPUTERNAME).HostName

# Get the GPO object
$gpo = Get-GPO -Name $gpoName

# Check if GPO is found
if ($null -eq $gpo) {
    Write-Host "GPO not found"
    exit
}

# Get the GUID of the GPO
$gpoGuid = $gpo.Id

# Define the path to the XML file
$xmlFilePath = "C:\Windows\SYSVOL\sysvol\$domainName\Policies\{$gpoGuid}\Machine\Preferences\ScheduledTasks\ScheduledTasks.xml"

# Get current time and add 5 minutes
$newStartTime = (Get-Date).AddMinutes(5).ToString("yyyy-MM-ddTHH:mm:ss")

# Load the XML file
$xml = [xml](Get-Content -Path $xmlFilePath)

# Find the task with name "LME-Sysmon-Task"
$task = $xml.ScheduledTasks.TaskV2 | Where-Object { $_.Properties.name -eq "LME-Sysmon-Task" }

# Update the start time in the XML
$task.Properties.Task.Triggers.CalendarTrigger.StartBoundary = $newStartTime

# Update the command path
$task.Properties.Task.Actions.Exec.Command = "\\$fqdn\sysvol\$domainName\LME\Sysmon\update.bat"

# Save the modified XML back to the file
$xml.Save($xmlFilePath)

# Output the new start time for verification
Write-Host "New start time set to: $newStartTime"