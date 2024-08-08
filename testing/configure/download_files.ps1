param(
    [string]$Directory = $env:USERPROFILE
)

# Base directory path - use provided username or default to USERPROFILE
$BaseDirectoryPath = if ($Directory -and ($Directory -ne $env:USERPROFILE)) {
    "C:\$Directory"
} else {
    "$env:USERPROFILE\Downloads\"
}

# Todo: Allow for downloading a version by adding a parameter for the version number
$ApiUrl = "https://api.github.com/repos/cisagov/LME/releases/latest"
$latestRelease = Invoke-RestMethod -Uri $ApiUrl
$zipFileUrl = $latestRelease.assets | Where-Object { $_.content_type -eq 'application/zip' } | Select-Object -ExpandProperty browser_download_url
$downloadPath = "$BaseDirectoryPath\" + $latestRelease.name + ".zip"
$extractPath = "$BaseDirectoryPath\LME"

Invoke-WebRequest -Uri $zipFileUrl -OutFile $downloadPath
if (-not (Test-Path -Path $extractPath)) {
    New-Item -ItemType Directory -Path $extractPath
}
Expand-Archive -LiteralPath $downloadPath -DestinationPath $extractPath
