#!/bin/bash

get_script_path() {
    local source="${BASH_SOURCE[0]}"
    while [ -h "$source" ]; do
        local dir="$(cd -P "$(dirname "$source")" && pwd)"
        source="$(readlink "$source")"
        [[ $source != /* ]] && source="$dir/$source"
    done
    echo "$(cd -P "$(dirname "$source")" && pwd)"
}

SCRIPT_DIR="$(get_script_path)"

HEADERS=(
  -H "kbn-version: 8.18.8"
  -H "kbn-xsrf: kibana"
  -H 'Content-Type: application/json'
)

# Function to check if Fleet API is ready
check_fleet_ready() {
    local response
    response=$(curl -k -s --user "elastic:${elastic}" \
        "${HEADERS[@]}" \
        "${LOCAL_KBN_URL}/api/fleet/settings")

    if [[ "$response" == *"Kibana server is not ready yet"* ]]; then
        return 1
    else
        return 0
    fi
}

# Wait for Fleet API to be ready
wait_for_fleet() {
    echo "Waiting for Fleet API to be ready..."
    max_attempts=60
    attempt=1
    while ! check_fleet_ready; do
        if [ $attempt -ge $max_attempts ]; then
            echo "Fleet API did not become ready after $max_attempts attempts. Exiting."
            exit 1
        fi
        echo "Attempt $attempt: Fleet API not ready. Waiting 10 seconds..."
        sleep 10
        attempt=$((attempt + 1))
    done
    echo "Fleet API is ready. Proceeding with configuration..."
}

#main:
source /opt/lme/lme-environment.env

# Set the secrets values and export them (source instead of execute)
set -a
. $SCRIPT_DIR/extract_secrets.sh -q 

wait_for_fleet