#!/bin/bash

set -e

ES_PORT="9200"
ES_PROTOCOL="https"
ENV_FILE="/opt/lme/lme-environment"

# Function to get the host IP address
get_host_ip() {
    hostname -I | awk '{print $1}'
}

ES_HOST=$(get_host_ip)

# Function to source environment file and set credentials
set_credentials_from_file() {
    if [ -f "$ENV_FILE" ]; then
        source "$ENV_FILE"
        if [ -n "$ELASTIC_USERNAME" ] && [ -n "$ELASTIC_PASSWORD" ]; then
            ES_USER="$ELASTIC_USERNAME"
            ES_PASS="$ELASTIC_PASSWORD"
            return 0
        fi
    fi
    return 1
}

# Function to check Elasticsearch connection and version
check_es_connection() {
    local response
    local http_code
    response=$(curl -s -k -u "${ES_USER}:${ES_PASS}" -w "\n%{http_code}" "${ES_PROTOCOL}://${ES_HOST}:${ES_PORT}")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ]; then
        es_version=$(echo "$body" | jq -r '.version.number')
        if [[ "${es_version}" =~ ^8\. ]]; then
            echo "Successfully connected to Elasticsearch version ${es_version}"
            return 0
        else
            echo "Unsupported Elasticsearch version: ${es_version}. This script supports Elasticsearch 8.x."
            return 1
        fi
    elif [ "$http_code" = "401" ]; then
        echo "Authentication failed. Please check your username and password."
        return 1
    else
        echo "Failed to connect to Elasticsearch. HTTP status code: ${http_code}"
        return 1
    fi
}

# Function to increase field limit
increase_field_limit() {
    local index_name="$1"
    local new_limit="$2"

    echo "Increasing field limit for index ${index_name} to ${new_limit}..."
    curl -X PUT -k -H 'Content-Type: application/json' \
         -u "${ES_USER}:${ES_PASS}" \
         "${ES_PROTOCOL}://${ES_HOST}:${ES_PORT}/${index_name}/_settings" \
         -d "{\"index.mapping.total_fields.limit\": ${new_limit}}"
    echo
}

# Function to import data and mappings using Podman and elasticdump
import_data_and_mappings() {
    local data_file="$1"
    local mappings_file="$2"
    local import_index="$3"
    local field_limit="$4"

    # Create the index with increased field limit
    echo "Creating index ${import_index} with increased field limit..."
    curl -X PUT -k -H 'Content-Type: application/json' \
         -u "${ES_USER}:${ES_PASS}" \
         "${ES_PROTOCOL}://${ES_HOST}:${ES_PORT}/${import_index}" \
         -d "{\"settings\": {\"index.mapping.total_fields.limit\": ${field_limit}}}"
    echo

    echo "Importing mappings from ${mappings_file} into index ${import_index}..."
    gzip -dc "${mappings_file}" | podman run --rm -i \
        --network host \
        -e NODE_TLS_REJECT_UNAUTHORIZED=0 \
        docker.io/elasticdump/elasticsearch-dump:latest \
        --input=$ \
        --output=${ES_PROTOCOL}://${ES_USER}:${ES_PASS}@${ES_HOST}:${ES_PORT}/${import_index} \
        --type=mapping \
        --headers='{"Content-Type": "application/json"}' \
        --sslVerification=false

    echo "Importing data from ${data_file} into index ${import_index}..."
    gzip -dc "${data_file}" | podman run --rm -i \
        --network host \
        -e NODE_TLS_REJECT_UNAUTHORIZED=0 \
        docker.io/elasticdump/elasticsearch-dump:latest \
        --input=$ \
        --output=${ES_PROTOCOL}://${ES_USER}:${ES_PASS}@${ES_HOST}:${ES_PORT}/${import_index} \
        --type=data \
        --headers='{"Content-Type": "application/json"}' \
        --sslVerification=false
}

# Function to prompt for password securely
prompt_password() {
    local prompt="$1"
    local password
    while IFS= read -p "$prompt" -r -s -n 1 char
    do
        if [[ $char == $'\0' ]]; then
            break
        fi
        prompt='*'
        password+="$char"
    done
    echo "$password"
}

# Main script
echo "LME Data Import Script for Elasticsearch 8.x (using Podman)"
echo "=========================================================="

echo "Using host IP: ${ES_HOST}"

# Check if Podman is installed
if ! command -v podman &> /dev/null; then
    echo "Error: Podman is not installed. Please install Podman to proceed."
    exit 1
fi


# Prompt for Elasticsearch credentials and verify connection
while true; do
    read -p "Enter Elasticsearch username: " ES_USER
    ES_PASS=$(prompt_password "Enter Elasticsearch password: ")
    echo  # Move to a new line after password input

    if check_es_connection; then
        break
    else
        echo "Would you like to try again? (y/n)"
        read -r retry
        if [[ ! $retry =~ ^[Yy]$ ]]; then
            echo "Exiting script."
            exit 1
        fi
    fi
done

# Try to set credentials from file
if set_credentials_from_file; then
    echo "Using credentials from $ENV_FILE"
else
    echo "Credentials not found in $ENV_FILE. Please enter them manually."
    # Prompt for Elasticsearch credentials and verify connection
    while true; do
        read -p "Enter Elasticsearch username: " ES_USER
        ES_PASS=$(prompt_password "Enter Elasticsearch password: ")
        echo  # Move to a new line after password input

        if check_es_connection; then
            break
        else
            echo "Would you like to try again? (y/n)"
            read -r retry
            if [[ ! $retry =~ ^[Yy]$ ]]; then
                echo "Exiting script."
                exit 1
            fi
        fi
    done
fi


# Prompt for input files
read -p "Enter the path to the compressed data file (winlogbeat_data.json.gz): " DATA_FILE
read -p "Enter the path to the compressed mappings file (winlogbeat_mappings.json.gz): " MAPPINGS_FILE

if [ ! -f "$DATA_FILE" ] || [ ! -f "$MAPPINGS_FILE" ]; then
    echo "Error: One or both files not found."
    exit 1
fi

# Prompt for import index name
read -p "Enter the name of the index to import into (default: winlogbeat-imported): " IMPORT_INDEX
IMPORT_INDEX=${IMPORT_INDEX:-winlogbeat-imported}

# Prompt for field limit
read -p "Enter the new field limit (default: 3000): " FIELD_LIMIT
FIELD_LIMIT=${FIELD_LIMIT:-3000}

# Import data and mappings with increased field limit
import_data_and_mappings "$DATA_FILE" "$MAPPINGS_FILE" "$IMPORT_INDEX" "$FIELD_LIMIT"

echo "Data and mappings import completed into index: $IMPORT_INDEX"