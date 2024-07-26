function Format-AzVmRunCommandOutput {
    param (
        [Parameter(Mandatory = $true)]
        [string]$JsonResponse
    )

    $results = @()

    try {
        $responseObj = $JsonResponse | ConvertFrom-Json
#        Write-Output "Converted JSON object: $responseObj"

        if ($responseObj -and $responseObj.value) {
            $stdout = ""
            $stderr = ""

            foreach ($item in $responseObj.value) {
#                Write-Output "Processing item: $($item.code)"

                # Check for StdOut and StdErr
                if ($item.code -like "ComponentStatus/StdOut/*") {
                    $stdout += $item.message + "`n"
                } elseif ($item.code -like "ComponentStatus/StdErr/*") {
                    $stderr += $item.message + "`n"
                }

                # Additional case to handle other types of 'code'
                # This ensures that all messages are captured
                else {
                    $stdout += $item.message + "`n"
                }
            }

            if ($stdout -or $stderr) {
                $results += New-Object PSObject -Property @{
                    StdOut = $stdout
                    StdErr = $stderr
                }
            }
        }
    } catch {
        $errorMessage = $_.Exception.Message
        Write-Output "Error: $errorMessage"
        $results += New-Object PSObject -Property @{
            StdOut = "Error: $errorMessage"
            StdErr = ""
        }
    }

    if (-not $results) {
        $results += New-Object PSObject -Property @{
            StdOut = "No data or invalid data received."
            StdErr = ""
        }
    }

    return $results
}

function Show-FormattedOutput {
    param (
        [Parameter(Mandatory = $true)]
        [Object[]]$FormattedOutput
    )

    foreach ($item in $FormattedOutput) {
        if ($item -is [string]) {
            # Handle string messages (like error or informational messages)
            Write-Output $item
        }
        elseif ($item -is [PSCustomObject]) {
            # Handle custom objects with StdOut and StdErr
            if (![string]::IsNullOrWhiteSpace($item.StdOut)) {
                Write-Output "Output (stdout):"
                Write-Output $item.StdOut
            }
            if (![string]::IsNullOrWhiteSpace($item.StdErr)) {
                Write-Output "Error (stderr):"
                Write-Output $item.StdErr
            }
        }
    }
}

function Get-PrivateKeyFromJson {
    param (
        [Parameter(Mandatory = $true)]
        [string]$jsonResponse
    )

    try {
        # Convert the JSON string to a PowerShell object
        $responseObj = $jsonResponse | ConvertFrom-Json

        # Extract the 'message' field
        $message = $responseObj.value[0].message

        # Define the start and end markers for the private key
        $startMarker = "-----BEGIN OPENSSH PRIVATE KEY-----"
        $endMarker = "-----END OPENSSH PRIVATE KEY-----"

        # Find the positions of the start and end markers
        $startPosition = $message.IndexOf($startMarker)
        $endPosition = $message.IndexOf($endMarker)

        if ($startPosition -lt 0 -or $endPosition -lt 0) {
            Write-Error "Private key markers not found in the JSON response."
            return $null
        }

        # Extract the private key, including the markers
        $privateKey = $message.Substring($startPosition, $endPosition - $startPosition + $endMarker.Length)

        # Return the private key
        return $privateKey
    }
    catch {
        Write-Error "An error occurred while extracting the private key: $_"
        return $null
    }
}

function Invoke-GPUpdateOnVMs {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroup,
        [int]$numberOfClients = 2
    )

    for ($i = 1; $i -le $numberOfClients; $i++) {
        $vmName = "C$i" # Dynamically create VM name

        # Invoke the command on the VM
        $gpupdateResponse = az vm run-command invoke `
          --command-id RunPowerShellScript `
          --name $vmName `
          --resource-group $ResourceGroup `
          --scripts "gpupdate /force"

        # Call the existing Show-FormattedOutput function
        Show-FormattedOutput -FormattedOutput (Format-AzVmRunCommandOutput -JsonResponse "$gpupdateResponse")
    }
}
