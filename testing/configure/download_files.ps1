param(
    [string]$directory = $env:USERPROFILE
)

# Base directory path - use provided username or default to USERPROFILE
$baseDirectoryPath = if ($directory -and ($directory -ne $env:USERPROFILE)) {
    "C:\$directory"
} else {
    "$env:USERPROFILE\Downloads\"
}

# Todo: Allow for downloading a version by adding a parameter for the version number
$apiUrl = "https://api.github.com/repos/cisagov/LME/releases/latest"
$latestRelease = Invoke-RestMethod -Uri $apiUrl
$zipFileUrl = $latestRelease.assets | Where-Object { $_.content_type -eq 'application/zip' } | Select-Object -ExpandProperty browser_download_url
$downloadPath = "$baseDirectoryPath\" + $latestRelease.name + ".zip"
$extractPath = "$baseDirectoryPath\LME"

Invoke-WebRequest -Uri $zipFileUrl -OutFile $downloadPath
if (-not (Test-Path -Path $extractPath)) {
    New-Item -ItemType Directory -Path $extractPath
}
Expand-Archive -LiteralPath $downloadPath -DestinationPath $extractPath
