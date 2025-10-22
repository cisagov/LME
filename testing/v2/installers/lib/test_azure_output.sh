#!/usr/bin/env bash

# Test script to debug Azure CLI output parsing
# This script helps understand what the Azure CLI returns and how to parse it

# Default values
RESOURCE_GROUP=""
VM_NAME=""
DEBUG_MODE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        --vm-name)
            VM_NAME="$2"
            shift 2
            ;;
        --debug)
            DEBUG_MODE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 --resource-group <rg> --vm-name <vm> [--debug]"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$RESOURCE_GROUP" ]]; then
    echo "Error: --resource-group is required"
    exit 1
fi

if [[ -z "$VM_NAME" ]]; then
    echo "Error: --vm-name is required"
    exit 1
fi

echo "Testing Azure CLI output parsing..."
echo "Resource Group: $RESOURCE_GROUP"
echo "VM Name: $VM_NAME"
echo "Debug Mode: $DEBUG_MODE"
echo ""

# Test 1: Simple command that should produce output
echo "Test 1: Simple Write-Host command"
test_command='Write-Host "Hello from Azure Windows VM"'

echo "Running: $test_command"
result=$(az vm run-command invoke \
    --command-id RunPowerShellScript \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --scripts "$test_command" \
    --output json 2>/dev/null)

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to run test command"
    exit 1
fi

echo "Raw JSON response:"
echo "$result" | jq '.' 2>/dev/null || echo "$result"
echo ""

# Test 2: Command that should produce error output
echo "Test 2: Command that should produce error output"
test_command='Write-Error "This is a test error message"'

echo "Running: $test_command"
result=$(az vm run-command invoke \
    --command-id RunPowerShellScript \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --scripts "$test_command" \
    --output json 2>/dev/null)

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to run test command"
    exit 1
fi

echo "Raw JSON response:"
echo "$result" | jq '.' 2>/dev/null || echo "$result"
echo ""

# Test 3: Command that should produce both stdout and stderr
echo "Test 3: Command that should produce both stdout and stderr"
test_command='Write-Host "This is stdout"; Write-Error "This is stderr"'

echo "Running: $test_command"
result=$(az vm run-command invoke \
    --command-id RunPowerShellScript \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --scripts "$test_command" \
    --output json 2>/dev/null)

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to run test command"
    exit 1
fi

echo "Raw JSON response:"
echo "$result" | jq '.' 2>/dev/null || echo "$result"
echo ""

echo "Test 4: Parsing output using improved logic"
test_command='Write-Host "Test output for parsing"; Write-Error "Test error for parsing"'

echo "Running: $test_command"
result=$(az vm run-command invoke \
    --command-id RunPowerShellScript \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --scripts "$test_command" \
    --output json 2>/dev/null)

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to run test command"
    exit 1
fi

if command -v jq >/dev/null 2>&1; then
    echo "Parsing with jq..."

    # List codes present
    echo "Codes present:"
    echo "$result" | jq -r '.value[] | .code'
    echo ""

    # Concise, readable parsed output (preferred filters)
    stdout_parsed=$(echo "$result" | jq -r '.value[] | select(.code | startswith("ComponentStatus/StdOut/")) | .message')
    stderr_parsed=$(echo "$result" | jq -r '.value[] | select(.code | startswith("ComponentStatus/StdErr/")) | .message')

    echo "Readable parsed output:"
    echo "StdOut:"
    if [[ -z "$stdout_parsed" ]]; then
        echo "(none)"
    else
        echo "$stdout_parsed"
    fi
    echo ""
    echo "StdErr:"
    if [[ -z "$stderr_parsed" ]]; then
        echo "(none)"
    else
        echo "$stderr_parsed"
    fi
    echo ""
    
    # Minimal structure check
    echo "Structure summary:"
    echo "$result" | jq '.value[] | {code: .code, messageLen: (.message|tostring|length)}' || echo "Failed to analyze JSON structure"
else
    echo "jq not available, using fallback parsing..."
    stdout=$(echo "$result" | grep -o '"message":"[^"]*"' | sed 's/"message":"//g' | sed 's/"$//g' | tr '\n' ' ')
    echo "Fallback parsing result: '$stdout'"
fi

echo ""
echo "Test completed!"
