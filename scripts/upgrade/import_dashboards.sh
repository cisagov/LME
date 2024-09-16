#!/bin/bash

# Get the directory of the current script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ENV_FILE="/opt/lme/lme-environment"

# Function to display usage information
usage() {
    echo "Usage: $0 -d DIRECTORY [OPTIONS]"
    echo "Options:"
    echo "  -d, --directory PATH      Path to the dashboards directory (required)"
    echo "  -h, --help                Display this help message"
    echo "Note: The script will use credentials from $ENV_FILE if available,"
    echo "      or prompt for them if not set."
    exit 1
}

# Function to read password securely
read_password() {
    read -s -p "Enter Elasticsearch password: " PASSWORD
    echo
}

# Function to source environment file and set credentials
set_credentials_from_file() {
    if [ -f "$ENV_FILE" ]; then
        source "$ENV_FILE"
        if [ -n "$ELASTIC_USERNAME" ] && [ -n "$ELASTIC_PASSWORD" ]; then
            USER="$ELASTIC_USERNAME"
            PASSWORD="$ELASTIC_PASSWORD"
            return 0
        fi
    fi
    return 1
}

# Initialize variables
DASHBOARDS_DIR=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -d|--directory)
            DASHBOARDS_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Check if dashboards directory is provided
if [ -z "$DASHBOARDS_DIR" ]; then
    echo "Error: Dashboards directory (-d) is required."
    usage
fi

# Try to set credentials from file
if set_credentials_from_file; then
    echo "Using credentials from $ENV_FILE"
else
    echo "Credentials not found in $ENV_FILE. Please enter them manually."
    read -p "Enter Elasticsearch username: " USER
    read_password
fi

# Check if the dashboards directory exists
if [ ! -d "$DASHBOARDS_DIR" ]; then
    echo "Error: Dashboards directory not found: $DASHBOARDS_DIR"
    exit 1
fi

# Convert DASHBOARDS_DIR to absolute path
DASHBOARDS_DIR=$(realpath "$DASHBOARDS_DIR")

# Check if fix_dashboard_titles.sh exists in the same directory as this script
FIX_SCRIPT="${SCRIPT_DIR}/fix_dashboard_titles.sh"
if [ ! -f "$FIX_SCRIPT" ]; then
    echo "Error: fix_dashboard_titles.sh not found in the script directory: $SCRIPT_DIR"
    exit 1
fi

# Make fix_dashboard_titles.sh executable
chmod +x "$FIX_SCRIPT"

# Run fix_dashboard_titles.sh with the DASHBOARDS_DIR
echo "Fixing dashboard titles in $DASHBOARDS_DIR..."
"$FIX_SCRIPT" "$DASHBOARDS_DIR"

# Check the exit status of fix_dashboard_titles.sh
if [ $? -ne 0 ]; then
    echo "Error: fix_dashboard_titles.sh failed. Exiting."
    exit 1
fi

# Get list of dashboard files
IFS=$'\n'
DASHBOARDS=($(ls -1 "${DASHBOARDS_DIR}"/*.ndjson))

# Check if any dashboard files were found
if [ ${#DASHBOARDS[@]} -eq 0 ]; then
    echo "Error: No dashboard files found in $DASHBOARDS_DIR"
    exit 1
fi

echo "Found ${#DASHBOARDS[@]} dashboard files."

# Upload dashboards
for db in "${DASHBOARDS[@]}"; do
    echo "Uploading ${db##*/} dashboard"
    curl -X POST -k --user "${USER}:${PASSWORD}" -H 'kbn-xsrf: true' --form file="@${db}" "https://127.0.0.1/api/saved_objects/_import?overwrite=true"
    echo
done

echo "Dashboard update completed."