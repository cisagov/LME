function Run-ExternalCommand {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Command
    )
    & cmd /c $Command
    if ($LASTEXITCODE -ne 0) {
        Write-Host "An error occurred running '$Command', exit code was $LASTEXITCODE"
        exit $LASTEXITCODE
    }
}

# Now use this function to run external commands
Run-ExternalCommand -Command "az login --service-principal -u `"$AZURE_CLIENT_ID`" -p `"$env:AZURE_SECRET`" --tenant `"$env:AZURE_TENANT`""
