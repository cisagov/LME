$ErrorActionPreference = 'Stop'
try {
    az login --service-principal -u $AZURE_CLIENT_ID -p $env:AZURE_SECRET --tenant $env:AZURE_TENANT
} catch {
    Write-Host "An error occurred: $_"
    exit 1
}
