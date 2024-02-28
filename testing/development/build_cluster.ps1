try {
    $output = az login --service-principal -u  -p $env:AZURE_SECRET --tenant $env:AZURE_TENANT 2>&1
    Write-Output $output
} catch {
    Write-Error $_
    exit 1
}



