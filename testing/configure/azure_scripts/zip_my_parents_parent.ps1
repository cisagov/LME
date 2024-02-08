<#
.SYNOPSIS
Zips the parent of the parent directory of the script and outputs the path of the ZIP file.

.DESCRIPTION
This script compresses the parent directory of the parent of its location into a ZIP file.
It then outputs the full path of the created ZIP file. This is useful for quickly archiving the contents of the parent directory.

.EXAMPLE
This example demonstrates how to execute the script and capture the path of the created ZIP file.
# Define the path to this zip script
$zipScriptPath = "C:\path\to\zip_my_parents_parent.ps1"

# Execute the zip script and capture the output (filename of the zip file)
$zipFilePath = & $zipScriptPath

.NOTES
- Ensure that PowerShell 5.0 or later is installed, as this script uses the Compress-Archive cmdlet.
- The script assumes read and write permissions in the script's and its parent directory.
#>
# Get the full path of the script's parent directory
$scriptParentDir = Split-Path -Parent $PSScriptRoot

# Get the name of the parent directory
$parentDirName = Split-Path -Leaf $scriptParentDir

# Define the destination path for the zip file (adjacent to the parent directory)
$destinationZipPath = Join-Path -Path (Split-Path -Parent $scriptParentDir) -ChildPath ("$parentDirName.zip")

# Create the zip file
Compress-Archive -Path "$scriptParentDir\*" -DestinationPath $destinationZipPath -Force

# Output the path of the created zip file
$destinationZipPath
