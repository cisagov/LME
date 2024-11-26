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
        az login
    fi

    if [ $? -ne 0 ]; then
        echo "Failed to authenticate to Azure"
        exit 1
    fi
}

# Function to get SAS URL for blob
get_sas_url() {
    local storage_account="$1"
    local container_name="$2"
    local blob_name="$3"
    local storage_key="$4"
    
    # Generate SAS token with read permission valid for 24 hours
    local expiry_date=$(date -u -d "1 day" '+%Y-%m-%dT%H:%MZ')
    
    local sas_token=$(az storage blob generate-sas \
        --account-name "$storage_account" \
        --account-key "$storage_key" \
        --container-name "$container_name" \
        --name "$blob_name" \
        --permissions r \
        --expiry "$expiry_date" \
        --output tsv)
    
    if [ $? -ne 0 ]; then
        echo "Failed to generate SAS token"
        exit 1
    fi
    
    echo "https://${storage_account}.blob.core.windows.net/${container_name}/${blob_name}?${sas_token}"
}

# Function to download file using curl
download_file() {
    local url="$1"
    local output_path="$2"
    
    echo "Downloading file to: $output_path"
    curl -sS -L -o "$output_path" "$url"
    
    if [ $? -eq 0 ]; then
        echo "File downloaded successfully to: $output_path"
    else
        echo "Failed to download file"
        exit 1
    fi
}

# Main script
main() {
    # Initialize variables from either environment or user input
    local storage_account="${AZURE_STORAGE_ACCOUNT:-}"
    local container_name="${AZURE_STORAGE_CONTAINER:-}"
    local blob_name="${AZURE_STORAGE_BLOB:-}"
    local storage_key="${AZURE_STORAGE_KEY:-}"
    local destination_path="${AZURE_DOWNLOAD_PATH:-}"

    # If any required variable is not set in environment, prompt for it
    if [ -z "$storage_account" ]; then
        read -p "Enter Storage Account Name: " storage_account
    fi

    if [ -z "$container_name" ]; then
        read -p "Enter Container Name: " container_name
    fi

    if [ -z "$blob_name" ]; then
        read -p "Enter Blob Name (file name in container): " blob_name
    fi

    if [ -z "$storage_key" ]; then
        read -sp "Enter Storage Account Key: " storage_key
        echo
    fi

    if [ -z "$destination_path" ]; then
        read -p "Enter local destination path: " destination_path
    fi

    # Validate all required variables are set
    if [[ -z "$storage_account" ]] || [[ -z "$container_name" ]] || [[ -z "$blob_name" ]] || [[ -z "$storage_key" ]] || [[ -z "$destination_path" ]]; then
        echo "Error: All required parameters must be provided either via environment variables or user input"
        exit 1
    fi

    # Create destination directory if it doesn't exist
    destination_dir=$(dirname "$destination_path")
    mkdir -p "$destination_dir"

    # Authenticate to Azure
    authenticate_azure

    # Get SAS URL
    echo "Generating SAS URL..."
    download_url=$(get_sas_url "$storage_account" "$container_name" "$blob_name" "$storage_key")

    # Download the file
    download_file "$download_url" "$destination_path"
}

# Run the script
main
