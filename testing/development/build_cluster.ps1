$ErrorActionPreference = 'Stop'
az login --service-principal -u $env:AZURE_CLIENT_ID -p $env:AZURE_SECRET --tenant $env:AZURE_TENANT
cd testing
./SetupTestbed.ps1