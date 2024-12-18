#!/usr/bin/env bash

# Function to handle errors
handle_error() {
    echo "Error: $1" >&2
    exit 1
}

# Check if ES_PASSWORD is set
if [ -z "$ES_PASSWORD" ]; then
    handle_error "ES_PASSWORD environment variable is not set"
fi

# Set default type and allow override via argument
TYPE="linux"
if [ "$1" = "windows" ]; then
    TYPE="windows"
fi

# Initialize retry variables
MAX_ATTEMPTS=100
ATTEMPT=1
WAIT_TIME=15

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    echo "Attempt $ATTEMPT of $MAX_ATTEMPTS to check agent reporting for $TYPE type..."
    
    if [ $ATTEMPT -gt 1 ]; then
        echo "Waiting before next attempt..."
        sleep $WAIT_TIME
    fi
    
    ATTEMPT=$((ATTEMPT + 1))

    # Run the curl command and capture the output
    output=$(curl -kL -s -X GET "https://localhost:9200/metrics-endpoint.metadata-*/_search" \
         -H 'Content-Type: application/json' \
         -H "kbn-xsrf: true" \
         -u "elastic:$ES_PASSWORD" \
         -d '{
      "query": {
        "bool": {
          "must": [
            {
              "term": {
                "host.os.type": "'$TYPE'"
              }
            }
          ]
        }
      },
      "sort": [
        {
          "@timestamp": {
            "order": "desc"
          }
        }
      ],
      "size": 1
    }') || { echo "Failed to connect to Elasticsearch, retrying..."; continue; }

    # Check if the output is valid JSON
    if ! echo "$output" | jq . >/dev/null 2>&1; then
        echo "Invalid JSON response from Elasticsearch, retrying..."
        continue
    fi

    # Extract the hit count
    hit_count=$(echo "$output" | jq '.hits.total.value')

    # Check if hit_count is a number
    if ! [[ "$hit_count" =~ ^[0-9]+$ ]]; then
        echo "Unexpected response format, retrying..."
        continue
    fi

    echo "Hit count: $hit_count"

    # Check the hit count and exit if successful
    if [ "$hit_count" -gt 0 ]; then
        echo "$TYPE type agent is reporting"
        exit 0
    fi

    echo "No recent data from $TYPE type, retrying..."
done

echo "No recent data from $TYPE type after $MAX_ATTEMPTS attempts"
exit 1