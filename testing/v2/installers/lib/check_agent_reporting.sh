#!/usr/bin/env bash

# Function to handle errors
handle_error() {
    echo "Error: $1" >&2
    exit 1
}

# Run the curl command and capture the output
output=$(curl -k -s -X GET "https://localhost:9200/.ds-metrics-system.cpu-default-*/_search" \
     -H 'Content-Type: application/json' \
     -H "kbn-xsrf: true" \
     -u elastic:password1 \
     -d '{
  "query": {
    "bool": {
      "must": [
        {
          "term": {
            "host.name": "ubuntu-vm"
          }
        },
        {
          "term": {
            "event.module": "system"
          }
        },
        {
          "term": {
            "event.dataset": "system.cpu"
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
}') || handle_error "Failed to connect to Elasticsearch"

# Check if the output is valid JSON
if ! echo "$output" | jq . >/dev/null 2>&1; then
    handle_error "Invalid JSON response from Elasticsearch"
fi

# Extract the hit count
hit_count=$(echo "$output" | jq '.hits.total.value')

# Check if hit_count is a number
if ! [[ "$hit_count" =~ ^[0-9]+$ ]]; then
    handle_error "Unexpected response format"
fi

# Check the hit count and exit accordingly
if [ "$hit_count" -gt 0 ]; then
    echo "ubuntu-vm is reporting"
    exit 0
else
    echo "No recent data from ubuntu-vm"
    exit 1
fi
