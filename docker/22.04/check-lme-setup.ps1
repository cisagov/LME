# Default timeout in minutes (30 minutes)
$timeoutMinutes = 30
$startTime = Get-Date

# Function to check if timeout has been reached
function Test-Timeout {
    $currentTime = Get-Date
    $elapsedTime = ($currentTime - $startTime).TotalMinutes
    if ($elapsedTime -gt $timeoutMinutes) {
        Write-Host "ERROR: Setup timed out after $timeoutMinutes minutes"
        exit 1
    }
}

Write-Host "Starting LME setup check..."

# Main loop
while ($true) {
    # Check if the timeout has been reached
    Test-Timeout
    
    # Get the logs and check for completion
    $logs = docker compose exec lme journalctl -u lme-setup -o cat --no-hostname
    
    # Check for successful completion
    if ($logs -match "First-time initialization complete") {
        Write-Host "SUCCESS: LME setup completed successfully"
        exit 0
    }
    
    # Check for failure indicators
    if ($logs -match "failed=1") {
        Write-Host "ERROR: Ansible playbook reported failures"
        exit 1
    }
    
    # Track progress through the playbooks
    $recapCount = ($logs | Select-String "PLAY RECAP" -AllMatches).Matches.Count
    if ($recapCount -gt 0) {
        Write-Host "INFO: Detected $recapCount of 2 playbook completions..."
    }
    
    # Wait before next check (60 seconds)
    Start-Sleep -Seconds 60
} 