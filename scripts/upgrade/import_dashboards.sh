#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 -d DIRECTORY [OPTIONS]"
    echo "Options:"
    echo "  -d, --directory PATH      Path to the dashboards directory (required)"
    echo "  -u, --user USERNAME       Elasticsearch username (default: elastic)"
    echo "  -h, --help                Display this help message"
    echo "Note: The script will prompt for the password if ELASTIC_PASSWORD is not set."
    exit 1
}

# Function to read password securely
read_password() {
    if [ -t 0 ]; then
        read -s -p "Enter Elasticsearch password: " PASSWORD
        echo
    else
        read PASSWORD
    fi
}

# Initialize variables
USER="elastic"
PASSWORD=""
DASHBOARDS_DIR=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -u|--user)
            USER="$2"
            shift 2
            ;;
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

# Check for password
if [ -z "$ELASTIC_PASSWORD" ]; then
    echo "ELASTIC_PASSWORD is not set. Please enter the password."
    read_password
else
    echo "Using password from ELASTIC_PASSWORD environment variable."
    PASSWORD="$ELASTIC_PASSWORD"
fi

# Check if the dashboards directory exists
if [ ! -d "$DASHBOARDS_DIR" ]; then
    echo "Error: Dashboards directory not found: $DASHBOARDS_DIR"
    exit 1
fi

# Get list of dashboard files
IFS=$'\n'
DASHBOARDS=($(ls -1 "${DASHBOARDS_DIR}"*.ndjson))

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