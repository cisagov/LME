$ErrorActionPreference = 'Stop'
az login --service-principal -u $env:AZURE_CLIENT_ID -p $env:AZURE_SECRET --tenant $env:AZURE_TENANT
cd testing
./SetupTestbed.ps1 -AllowedSources "73.84.196.126/32" -l centralus -ResourceGroup LME-$env:UNIQUE_ID -m  -y
