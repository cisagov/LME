param (
    [Parameter()]
    [string]$baseDirectory = "C:\lme",

    [Parameter()]
    [string]$winlogbeatVersion = "winlogbeat-8.5.0-windows-x86_64"
)

# Source and destination directories
$sourceDir = "$baseDirectory\files_for_windows\tmp"
$destinationDir = "C:\Program Files"

# Copying files from source to destination
Copy-Item -Path "$sourceDir\*" -Destination $destinationDir -Recurse -Force

# Winlogbeat url
$url = "https://artifacts.elastic.co/downloads/beats/winlogbeat/$winlogbeatVersion.zip"

# Destination path where the file will be saved
$winlogbeatDestination = "$baseDirectory\$winlogbeatVersion.zip"

# Create the base directory if it does not exist
if (-not (Test-Path $baseDirectory)) {
    New-Item -ItemType Directory -Path $baseDirectory
}

# Download the file
Invoke-WebRequest -Uri $url -OutFile $winlogbeatDestination

# Unzip destination
$unzipDestination = "C:\Program Files\lme\$winlogbeatVersion"

# Unzip the file
Expand-Archive -LiteralPath $winlogbeatDestination -DestinationPath $unzipDestination

# Define the nested directory path
$nestedDir = Join-Path -Path $unzipDestination -ChildPath $winlogbeatVersion

# Move the contents of the nested directory up one level and remove the nested directory
if (Test-Path $nestedDir) {
    Get-ChildItem -Path $nestedDir -Recurse | Move-Item -Destination $unzipDestination
    Remove-Item -Path $nestedDir -Force -Recurse
}


# Define the path of the winlogbeat.yml file in C:\Program Files\lme
$winlogbeatYmlSource = "C:\Program Files\lme\winlogbeat.yml"

# Define the destination path of the winlogbeat.yml file
$winlogbeatYmlDestination = Join-Path -Path $unzipDestination -ChildPath "winlogbeat.yml"

# Move the winlogbeat.yml file to the destination directory, overwriting if it exists
Move-Item -Path $winlogbeatYmlSource -Destination $winlogbeatYmlDestination -Force

# Set execution policy to Unrestricted for this process
Set-ExecutionPolicy Unrestricted -Scope Process

# Define the full path of the install script
$installScriptPath = Join-Path -Path $unzipDestination -ChildPath "install-service-winlogbeat.ps1"

# Check if the install script exists
if (Test-Path $installScriptPath) {
    # Change directory to the unzip destination
    Push-Location -Path $unzipDestination

    # Run the install script
    .\install-service-winlogbeat.ps1

    # Return to the previous directory
    Pop-Location
}
else {
    Write-Host "The installation script was not found at $installScriptPath"
}

Start-Sleep -Seconds 5

# Start the winlogbeat service
try {
    Start-Service -Name "winlogbeat"
    Write-Host "Winlogbeat service started successfully."
}
catch {
    Write-Host "Failed to start Winlogbeat service: $_"
}
