#!/bin/bash

# Function to handle Azure authentication
authenticate_azure() {
    # Check if we're already authenticated
    if az account show >/dev/null 2>&1; then
        echo "Already authenticated to Azure"
        return 0
    fi

    # Check for service principal environment variables
    if [[ -n "$AZURE_CLIENT_ID" ]] && [[ -n "$AZURE_CLIENT_SECRET" ]] && [[ -n "$AZURE_TENANT_ID" ]]; then
        echo "Authenticating using service principal..."
        az login --service-principal \
            --username "$AZURE_CLIENT_ID" \
            --password "$AZURE_CLIENT_SECRET" \
            --tenant "$AZURE_TENANT_ID" >/dev/null 2>&1
    else
        echo "Authenticating interactively..."
        az login --use-device-code
    fi

    if [ $? -ne 0 ]; then
        echo "Failed to authenticate to Azure"
        exit 1
    fi
}

# Function to get storage account key
get_storage_key() {
    local resource_group="$1"
    local storage_account="$2"

    local storage_key=$(az storage account keys list \
        --resource-group "$resource_group" \
        --account-name "$storage_account" \
        --query "[0].value" \
        -o tsv)

    if [ $? -ne 0 ]; then
        echo "Failed to retrieve storage account key"
        exit 1
    fi

    echo "$storage_key"
}

# Main script
main() {
    # Add print_key flag
    local print_key=false
    while getopts "p" opt; do
        case $opt in
            p) print_key=true ;;
            \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
        esac
    done

    # Initialize variables from either environment or user input
    local resource_group="${AZURE_RESOURCE_GROUP:-}"
    local storage_account="${AZURE_STORAGE_ACCOUNT:-}"

    # Authenticate to Azure
    authenticate_azure

    # If resource group not provided in environment, list and prompt
    if [ -z "$resource_group" ]; then
        echo "Available Resource Groups:"
        az group list --query "[].name" -o tsv
        read -p "Enter the Resource Group name containing your storage account: " resource_group
    fi

    # If storage account not provided in environment, list and prompt
    if [ -z "$storage_account" ]; then
        echo "Available Storage Accounts in $resource_group:"
        az storage account list \
            --resource-group "$resource_group" \
            --query "[].name" \
            -o tsv
        read -p "Enter the Storage Account name: " storage_account
    fi

    # Validate required parameters
    if [[ -z "$resource_group" ]] || [[ -z "$storage_account" ]]; then
        echo "Error: Resource group and storage account must be provided either via environment variables or user input"
        exit 1
    fi

    # Get the storage account key
    echo "Fetching storage account key..."
    storage_key=$(get_storage_key "$resource_group" "$storage_account")

    # Only print if -p flag is used
    if [ "$print_key" = true ]; then
        echo
        echo "⚠️  Important: Keep this key secure and never share it publicly!"
        echo "Your storage account key is:"
        echo "$storage_key"
    fi

    export AZURE_STORAGE_KEY=$storage_key

    # If GITHUB_OUTPUT is set (running in GitHub Actions), append the key
    if [ -n "$GITHUB_OUTPUT" ]; then
        echo "AZURE_STORAGE_KEY=$storage_key" >> "$GITHUB_OUTPUT"
    fi
}

# Run the script
main "$@"
