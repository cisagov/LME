param(
    [string]$DomainName = "lme.local",  # Default domain name
    [string]$VMUsername = "admin.ackbar"  # Default VM username
)

# Define the SYSVOL path
$destinationPath = "C:\Windows\SYSVOL\SYSVOL\$DomainName\LME\Sysmon"
$tempPath = Join-Path $env:TEMP "SysmonTemp"

# Create the LME and Sysmon directories
New-Item -ItemType Directory -Path $destinationPath -Force
New-Item -ItemType Directory -Path $tempPath -Force

# Copy update.bat from the user's download directory
$updateBatSource = "C:\Users\$VMUsername\Downloads\LME\Chapter 2 Files\GPO Deployment\update.bat"
Copy-Item -Path $updateBatSource -Destination $destinationPath

# Download URL for Sysmon
$url = "https://download.sysinternals.com/files/Sysmon.zip"

# Download file path
$zipFilePath = Join-Path $tempPath "Sysmon.zip"

# Download the file
Invoke-WebRequest -Uri $url -OutFile $zipFilePath

# Unzip the file to temp directory
Expand-Archive -Path $zipFilePath -DestinationPath $tempPath

# Copy only Sysmon64.exe to destination
Copy-Item -Path "$tempPath\Sysmon64.exe" -Destination $destinationPath

# Clean up: remove temp directory and zip file
Remove-Item -Path $tempPath -Recurse -Force

# Download URL for the Sysmon configuration file
$xmlUrl = "https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml"

# Destination file path for the Sysmon configuration file
$xmlFilePath = Join-Path $destinationPath "sysmon.xml"

# Download and rename the file
Invoke-WebRequest -Uri $xmlUrl -OutFile $xmlFilePath

# Define the destination path for Sigcheck
$sigcheckDestinationPath = "C:\Windows\SYSVOL\SYSVOL\$DomainName\LME"

# Download URL for Sigcheck
$sigcheckUrl = "https://download.sysinternals.com/files/Sigcheck.zip"

# Temporary path for Sigcheck zip file
$sigcheckTempPath = Join-Path $env:TEMP "SigcheckTemp"

# Ensure the temporary directory exists
New-Item -ItemType Directory -Path $sigcheckTempPath -Force

# Download file path for Sigcheck
$sigcheckZipFilePath = Join-Path $sigcheckTempPath "Sigcheck.zip"

# Download the Sigcheck zip file
Invoke-WebRequest -Uri $sigcheckUrl -OutFile $sigcheckZipFilePath

# Unzip the Sigcheck file to temporary directory
Expand-Archive -Path $sigcheckZipFilePath -DestinationPath $sigcheckTempPath

# Copy only Sigcheck64.exe to the destination
Copy-Item -Path "$sigcheckTempPath\sigcheck64.exe" -Destination $sigcheckDestinationPath

# Clean up: remove temporary directory and zip file
Remove-Item -Path $sigcheckTempPath -Recurse -Force
