$ErrorActionPreference = 'Stop'
az login --service-principal -u $AZURE_CLIENT_ID -p $env:AZURE_SECRET --tenant $env:AZURE_TENANT
# if ($LASTEXITCODE -ne 0) {
#     Write-Host "Login failed with exit code $LASTEXITCODE"
#     exit $LASTEXITCODE
# }