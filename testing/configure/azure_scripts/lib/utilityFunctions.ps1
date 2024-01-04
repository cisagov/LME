function Format-AzVmRunCommandOutput {
    param (
        [Parameter(Mandatory=$true)]
        [string]$JsonResponse
    )

    # Initialize an empty array to hold the results
    $results = @()

    try {
        $responseObj = $JsonResponse | ConvertFrom-Json

        if ($responseObj -and $responseObj.value) {
            foreach ($item in $responseObj.value) {
                if ($item.message) {
                    $stdout = $item.message -split '\n\[stdout\]\n' | Select-Object -Last 1
                    $stdout = $stdout -split '\n\[stderr\]\n' | Select-Object -First 1
                    $stderr = $item.message -split '\n\[stderr\]\n' | Select-Object -Last 1

                    $results += New-Object PSObject -Property @{
                        StdOut = $stdout
                        StdErr = $stderr
                    }
                }
            }
        }
    }
    catch {
        # Return a custom object indicating an error
        $results += New-Object PSObject -Property @{
            StdOut = "Error: Invalid JSON response"
            StdErr = ""
        }
    }

    # Ensure that something is always returned
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
        [Parameter(Mandatory=$true)]
        [Object[]]$FormattedOutput
    )

    foreach ($item in $FormattedOutput) {
        if ($item -is [string]) {
            # Handle string messages (like error or informational messages)
            Write-Host $item
        }
        elseif ($item -is [PSCustomObject]) {
            # Handle custom objects with StdOut and StdErr
            Write-Host "Output (stdout):"
            Write-Host $item.StdOut
            Write-Host "Error (stderr):"
            Write-Host $item.StdErr
        }
    }
}

function ExtractPrivateKeyFromJson {
    param (
        [Parameter(Mandatory=$true)]
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
    } catch {
        Write-Error "An error occurred while extracting the private key: $_"
        return $null
    }
}