#!/bin/bash

set -e

LME_PATH="/opt/lme"
ES_PORT="9200"
ES_PROTOCOL="https"

# Function to get the host IP address
get_host_ip() {
    ip route get 1 | awk '{print $7;exit}'
}

ES_HOST=$(get_host_ip)

# Function to find the drive with the most free space
find_max_space_drive() {
    df -h | awk '
    BEGIN { max=0; maxdir="/" }
    {
        if (NR>1 && $1 !~ /^tmpfs/ && $1 !~ /^efivarfs/ && $1 !~ /^\/dev\/loop/) {
            gsub(/[A-Za-z]/, "", $4)
            if ($4+0 > max+0) {
                max = $4
                maxdir = $6
            }
        }
    }
    END { print maxdir }
    '
}

# Function to clean up path (remove double slashes)
clean_path() {
    echo "$1" | sed 's#//*#/#g'
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

# Function to export data using Docker and elasticdump
export_data() {
    local output_dir="$1"

    echo "Exporting winlogbeat-* indices..."
    
    docker run --rm -v "${output_dir}:/tmp" \
        --network host \
        -e NODE_TLS_REJECT_UNAUTHORIZED=0 \
        elasticdump/elasticsearch-dump \
        --input=${ES_PROTOCOL}://${ES_USER}:${ES_PASS}@${ES_HOST}:${ES_PORT}/winlogbeat-* \
        --output=/tmp/winlogbeat_data.json \
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
echo "LME Data Export Script for Elasticsearch 8.x"
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

# Determine backup location
echo "Choose backup directory:"
echo "1. Specify a directory"
echo "2. Automatically find directory with most space"
read -p "Enter your choice (1 or 2): " dir_choice

case $dir_choice in
    1)
        read -p "Enter the backup directory path: " BACKUP_DIR
        ;;
    2)
        max_space_dir=$(find_max_space_drive)
        BACKUP_DIR=$(clean_path "${max_space_dir}/lme_backup")
        echo "Directory with most free space: $BACKUP_DIR"
        read -p "Is this okay? (y/n): " confirm
        if [[ $confirm != [Yy]* ]]; then
            echo "Please run the script again and choose option 1 to specify a directory."
            exit 1
        fi
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

# Clean up the final BACKUP_DIR path
BACKUP_DIR=$(clean_path "$BACKUP_DIR")

# Create backup directory if it doesn't exist
mkdir -p "${BACKUP_DIR}"

# Export data
export_data "${BACKUP_DIR}"

echo "Data export completed. Backup stored in: ${BACKUP_DIR}"