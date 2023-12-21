# Execute 'wecutil gr lme' command and capture the output
$wecutilOutput = wecutil gr lme

# Split the output into individual lines
$lines = $wecutilOutput -split "`r`n" | Where-Object { $_ -match "\S" } # Exclude empty lines

# Initialize a list to store active computer names
$activeComputers = @()

# Process each line to extract computer names with active status
$isActive = $false
foreach ($line in $lines) {
    if ($line -match "RunTimeStatus: Active") {
        $isActive = $true
    } elseif ($line -match "\.local") {
        if ($isActive) {
            if ($line -match "(\S+\.local)") {
                $activeComputers += $matches[1]
            }
        }
        $isActive = $false
    }
}

# Display the active computer names
Write-Host "Active Computers Forwarding Events:"
$activeComputers | ForEach-Object { Write-Host $_ }
