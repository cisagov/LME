# Downloads latest release and unzips it in $USER\Downloads\LME

$apiUrl = "https://api.github.com/repos/cisagov/LME/releases/latest"
$latestRelease = Invoke-RestMethod -Uri $apiUrl
$zipFileUrl = $latestRelease.assets | Where-Object { $_.content_type -eq 'application/zip' } | Select-Object -ExpandProperty browser_download_url
$downloadPath = "$env:USERPROFILE\Downloads\" + $latestRelease.name + ".zip"
$extractPath = "$env:USERPROFILE\Downloads\LME"

Invoke-WebRequest -Uri $zipFileUrl -OutFile $downloadPath
if (-not (Test-Path -Path $extractPath)) {
    New-Item -ItemType Directory -Path $extractPath
}
Expand-Archive -LiteralPath $downloadPath -DestinationPath $extractPath
