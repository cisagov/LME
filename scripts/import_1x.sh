#!/bin/bash

set -e

ES_PORT="9200"
ES_PROTOCOL="https"

# Function to get the host IP address
get_host_ip() {
    ip route get 1 | awk '{print $7;exit}'
}

ES_HOST=$(get_host_ip)

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

# Function to import data using Docker and elasticdump
import_data() {
    local input_file="$1"

    echo "Importing data from ${input_file}..."
    
    gzip -dc "${input_file}" | docker run --rm -i \
        --network host \
        -e NODE_TLS_REJECT_UNAUTHORIZED=0 \
        elasticdump/elasticsearch-dump \
        --input=$ \
        --output=${ES_PROTOCOL}://${ES_USER}:${ES_PASS}@${ES_HOST}:${ES_PORT}/winlogbeat-imported \
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
echo "LME Data Import Script for Elasticsearch 8.x"
echo "============================================"

echo "Using host IP: ${ES_HOST}"

# Check if Docker is installed and running
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed. Please install Docker to proceed."
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "Error: Docker daemon is not running. Please start Docker to proceed."
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

# Prompt for input file
read -p "Enter the path to the compressed data file (.json.gz): " INPUT_FILE

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: File not found: $INPUT_FILE"
    exit 1
fi

# Import data
import_data "$INPUT_FILE"

echo "Data import completed."