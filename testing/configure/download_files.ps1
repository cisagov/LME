param(
    [string]$username = $env:USERPROFILE
)

# Base directory path - use provided username or default to USERPROFILE
$baseDirectoryPath = if ($username -and ($username -ne $env:USERPROFILE)) {
    "C:\Users\$username"
} else {
    $env:USERPROFILE
}

$apiUrl = "https://api.github.com/repos/cisagov/LME/releases/latest"
$latestRelease = Invoke-RestMethod -Uri $apiUrl
$zipFileUrl = $latestRelease.assets | Where-Object { $_.content_type -eq 'application/zip' } | Select-Object -ExpandProperty browser_download_url
$downloadPath = "$baseDirectoryPath\Downloads\" + $latestRelease.name + ".zip"
$extractPath = "$baseDirectoryPath\Downloads\LME"

Invoke-WebRequest -Uri $zipFileUrl -OutFile $downloadPath
if (-not (Test-Path -Path $extractPath)) {
    New-Item -ItemType Directory -Path $extractPath
}
Expand-Archive -LiteralPath $downloadPath -DestinationPath $extractPath
