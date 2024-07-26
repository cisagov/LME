param (
    [Parameter()]
    [string]$BaseDirectory = "C:\lme",

    [Parameter()]
    [string]$WinlogbeatVersion = "winlogbeat-8.5.0-windows-x86_64"
)

# Source and destination directories
$SourceDir = "$BaseDirectory\files_for_windows\tmp"
$DestinationDir = "C:\Program Files"

# Copying files from source to destination
Copy-Item -Path "$SourceDir\*" -Destination $DestinationDir -Recurse -Force

# Winlogbeat url
$Url = "https://artifacts.elastic.co/downloads/beats/winlogbeat/$WinlogbeatVersion.zip"

# Destination path where the file will be saved
$WinlogbeatDestination = "$BaseDirectory\$WinlogbeatVersion.zip"

# Unzip destination
$UnzipDestination = "C:\Program Files\lme\$WinlogbeatVersion"

# Define the path of the winlogbeat.yml file in C:\Program Files\lme
$WinlogbeatYmlSource = "C:\Program Files\lme\winlogbeat.yml"

# Define the destination path of the winlogbeat.yml file
$WinlogbeatYmlDestination = Join-Path -Path $UnzipDestination -ChildPath "winlogbeat.yml"

# Define the full path of the install script
$InstallScriptPath = Join-Path -Path $UnzipDestination -ChildPath "install-service-winlogbeat.ps1"

# Create the base directory if it does not exist
if (-not (Test-Path $BaseDirectory)) {
    New-Item -ItemType Directory -Path $BaseDirectory
}

# Download the file
Invoke-WebRequest -Uri $Url -OutFile $WinlogbeatDestination

# Unzip the file
Expand-Archive -LiteralPath $WinlogbeatDestination -DestinationPath $UnzipDestination

# Define the nested directory path
$nestedDir = Join-Path -Path $UnzipDestination -ChildPath $WinlogbeatVersion

# Move the contents of the nested directory up one level and remove the nested directory
if (Test-Path $nestedDir) {
    Get-ChildItem -Path $nestedDir -Recurse | Move-Item -Destination $UnzipDestination
    Remove-Item -Path $nestedDir -Force -Recurse
}

# Move the winlogbeat.yml file to the destination directory, overwriting if it exists
Move-Item -Path $WinlogbeatYmlSource -Destination $WinlogbeatYmlDestination -Force

# Set execution policy to Unrestricted for this process
Set-ExecutionPolicy Unrestricted -Scope Process

# Check if the install script exists
if (Test-Path $InstallScriptPath) {
    # Change directory to the unzip destination
    Push-Location -Path $UnzipDestination

    # Run the install script
    .\install-service-winlogbeat.ps1

    # Return to the previous directory
    Pop-Location
}
else {
    Write-Output "The installation script was not found at $InstallScriptPath"
}

Start-Sleep -Seconds 5

# Start the winlogbeat service
try {
    Start-Service -Name "winlogbeat"
    Write-Output "Winlogbeat service started successfully."
}
catch {
    Write-Output "Failed to start Winlogbeat service: $_"
}
