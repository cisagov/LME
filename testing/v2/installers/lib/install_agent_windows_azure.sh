#!/usr/bin/env bash

# Azure-native Windows Elastic Agent installer
# Uses Azure CLI 'az vm run-command' instead of SSH/minimega for remote Windows management

# Default values
VERSION="8.18.3"
ARCHITECTURE="windows-x86_64"
HOST_IP="10.1.0.5"
CLIENT_IP=""
RESOURCE_GROUP=""
VM_NAME="ws1"
PORT="8220"
ENROLLMENT_TOKEN=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            VERSION="$2"
            shift 2
            ;;
        --arch)
            ARCHITECTURE="$2"
            shift 2
            ;;
        --hostip)
            HOST_IP="$2"
            shift 2
            ;;
        --clientip)
            CLIENT_IP="$2"
            shift 2
            ;;
        --resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        --vm-name)
            VM_NAME="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --token)
            ENROLLMENT_TOKEN="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 --resource-group <rg> --vm-name <vm> --hostip <host> --token <token> [--version <ver>] [--port <port>]"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$RESOURCE_GROUP" ]]; then
    echo "Error: --resource-group is required"
    exit 1
fi

if [[ -z "$ENROLLMENT_TOKEN" ]]; then
    echo "Error: --token (enrollment token) is required"
    exit 1
fi

if [[ -z "$HOST_IP" ]]; then
    echo "Error: --hostip is required"
    exit 1
fi

echo "Installing Elastic Agent on Azure Windows VM..."
echo "Resource Group: $RESOURCE_GROUP"
echo "VM Name: $VM_NAME"
echo "Host IP: $HOST_IP"
echo "Version: $VERSION"

# Function to run PowerShell commands on Azure Windows VM
run_azure_powershell() {
    local command="$1"
    local description="$2"
    
    echo "Running: $description"
    
    # Use az vm run-command to execute PowerShell on the Windows VM
    local result=$(az vm run-command invoke \
        --command-id RunPowerShellScript \
        --resource-group "$RESOURCE_GROUP" \
        --name "$VM_NAME" \
        --scripts "$command" \
        --output json 2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to run command on Windows VM: $description"
        return 1
    fi
    
    # Extract and display the output
    local stdout=$(echo "$result" | jq -r '.value[0].message' 2>/dev/null || echo "No output")
    echo "Output: $stdout"
    
    return 0
}

# Step 1: Download Elastic Agent to Windows VM
echo "Step 1: Downloading Elastic Agent to Windows VM..."
download_command='
$url = "https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-'"$VERSION"'-'"$ARCHITECTURE"'.zip"
$output = "C:\elastic-agent-'"$VERSION"'-'"$ARCHITECTURE"'.zip"
Write-Host "Downloading from: $url"
Write-Host "Saving to: $output"
try {
    Invoke-WebRequest -Uri $url -OutFile $output -UseBasicParsing
    Write-Host "Download completed successfully"
    if (Test-Path $output) {
        $fileSize = (Get-Item $output).length
        Write-Host "File size: $fileSize bytes"
    }
} catch {
    Write-Host "Download failed: $($_.Exception.Message)"
    exit 1
}
'

if ! run_azure_powershell "$download_command" "Download Elastic Agent"; then
    echo "Failed to download Elastic Agent"
    exit 1
fi

# Step 2: Extract the archive
echo "Step 2: Extracting Elastic Agent archive..."
extract_command='
$zipPath = "C:\elastic-agent-'"$VERSION"'-'"$ARCHITECTURE"'.zip"
$extractPath = "C:\elastic-agent-extract"
Write-Host "Extracting $zipPath to $extractPath"
try {
    if (Test-Path $extractPath) {
        Remove-Item -Path $extractPath -Recurse -Force
    }
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
    Write-Host "Extraction completed"
    
    # List contents to verify extraction
    $contents = Get-ChildItem -Path $extractPath -Recurse -Name
    Write-Host "Extracted contents:"
    $contents | ForEach-Object { Write-Host "  $_" }
} catch {
    Write-Host "Extraction failed: $($_.Exception.Message)"
    exit 1
}
'

if ! run_azure_powershell "$extract_command" "Extract Elastic Agent"; then
    echo "Failed to extract Elastic Agent"
    exit 1
fi

# Step 3: Install Elastic Agent
echo "Step 3: Installing Elastic Agent..."
install_command='
$extractPath = "C:\elastic-agent-extract"
$agentPath = Get-ChildItem -Path $extractPath -Directory | Select-Object -First 1
$agentExePath = Join-Path -Path $agentPath.FullName -ChildPath "elastic-agent.exe"

Write-Host "Agent executable path: $agentExePath"

if (-not (Test-Path $agentExePath)) {
    Write-Host "Error: elastic-agent.exe not found at $agentExePath"
    exit 1
}

# Install the agent
$installArgs = @(
    "install"
    "--non-interactive"
    "--force"
    "--url=https://'"$HOST_IP"':'"$PORT"'"
    "--insecure"
    "--enrollment-token='"$ENROLLMENT_TOKEN"'"
)

Write-Host "Installing Elastic Agent with arguments: $($installArgs -join \" \")"

try {
    $process = Start-Process -FilePath $agentExePath -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
    Write-Host "Installation process exit code: $($process.ExitCode)"
    
    if ($process.ExitCode -eq 0) {
        Write-Host "Elastic Agent installation completed successfully"
    } else {
        Write-Host "Elastic Agent installation failed with exit code: $($process.ExitCode)"
        exit 1
    }
} catch {
    Write-Host "Installation failed: $($_.Exception.Message)"
    exit 1
}
'

if ! run_azure_powershell "$install_command" "Install Elastic Agent"; then
    echo "Failed to install Elastic Agent"
    exit 1
fi

# Step 4: Wait for service to start
echo "Step 4: Waiting for Elastic Agent service to start..."
sleep 60

# Step 5: Check agent service status
echo "Step 5: Checking Elastic Agent service status..."
status_command='
try {
    $service = Get-Service -Name "Elastic Agent" -ErrorAction SilentlyContinue
    if ($service) {
        Write-Host "Elastic Agent service status: $($service.Status)"
        if ($service.Status -eq "Running") {
            Write-Host "Elastic Agent service is running successfully"
        } else {
            Write-Host "Warning: Elastic Agent service is not running"
        }
    } else {
        Write-Host "Error: Elastic Agent service not found"
        exit 1
    }
} catch {
    Write-Host "Error checking service status: $($_.Exception.Message)"
    exit 1
}
'

if ! run_azure_powershell "$status_command" "Check Elastic Agent service"; then
    echo "Failed to check Elastic Agent service status"
    exit 1
fi

# Step 6: Cleanup downloaded files
echo "Step 6: Cleaning up temporary files..."
cleanup_command='
try {
    $zipPath = "C:\elastic-agent-'"$VERSION"'-'"$ARCHITECTURE"'.zip"
    $extractPath = "C:\elastic-agent-extract"
    
    if (Test-Path $zipPath) {
        Remove-Item -Path $zipPath -Force
        Write-Host "Removed: $zipPath"
    }
    
    if (Test-Path $extractPath) {
        Remove-Item -Path $extractPath -Recurse -Force
        Write-Host "Removed: $extractPath"
    }
    
    Write-Host "Cleanup completed"
} catch {
    Write-Host "Cleanup failed: $($_.Exception.Message)"
}
'

run_azure_powershell "$cleanup_command" "Cleanup temporary files"

echo "Elastic Agent installation on Azure Windows VM completed successfully!"
