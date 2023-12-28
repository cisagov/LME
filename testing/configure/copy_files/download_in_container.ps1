param(
    [Parameter(Mandatory=$true)]
    [string]$VMName,

    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$true)]
    [string]$FileDownloadUrl,

    [Parameter(Mandatory=$true)]
    [string]$DestinationFilePath,  # This will be stripped to only the filename

    [Parameter()]
    [string]$username = "admin.ackbar",

    [Parameter()]
    [ValidateSet("Windows","Linux","linux")]
    [string]$os = "Windows"
)

# Convert the OS parameter to lowercase for consistent comparison
$os = $os.ToLower()

# Extract just the filename from the destination file path
$DestinationFileName = Split-Path -Leaf $DestinationFilePath

# Set the destination path depending on the OS
if ($os -eq "linux") {
    $DestinationPath = "/home/$username/lme/$DestinationFileName"
    # Create the lme directory if it doesn't exist
    $DirectoryCreationScript = "mkdir -p '/home/$username/lme'"
    az vm run-command invoke `
        --command-id RunShellScript `
        --resource-group $ResourceGroupName `
        --name $VMName `
        --scripts $DirectoryCreationScript
} else {
    $DestinationPath = "C:\lme\$DestinationFileName"
}

# The download script
$DownloadScript = if ($os -eq "linux") {
    "curl -o '$DestinationPath' '$FileDownloadUrl'"
} else {
    "Invoke-WebRequest -Uri '$FileDownloadUrl' -OutFile '$DestinationPath'"
}

# Execute the download script
az vm run-command invoke `
    --command-id RunPowerShellScript `
    --resource-group $ResourceGroupName `
    --name $VMName `
    --scripts $DownloadScript
