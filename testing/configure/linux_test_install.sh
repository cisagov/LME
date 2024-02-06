#!/usr/bin/env bash
set -e

# Get the full path to the directory containing the current script
script_dir=$(dirname "$(realpath "${BASH_SOURCE[0]}")")

source "${script_dir}/lib/functions.sh"
extract_credentials '/opt/lme/Chapter 3 Files/output.log'

check_variable() {
    local var_name="$1"
    local var_value="$2"

    if [ -z "$var_value" ]; then
        echo "Error: '$var_name' is not set or is empty"
        return 1  # Return a non-zero status to indicate failure
    fi
}

# Perform the checks
check_variable "elastic" "$elastic" || exit 1
check_variable "kibana" "$kibana" || exit 1
check_variable "logstash_system" "$logstash_system" || exit 1
check_variable "logstash_writer" "$logstash_writer" || exit 1
check_variable "dashboard_update" "$dashboard_update" || exit 1

echo "All variables are set correctly."

# Get the list of containers and their health status
container_statuses=$(docker ps --format "{{.Names}}: {{.Status}}" | grep -v "CONTAINER ID")

# Check each container's status
unhealthy=false
while read -r line; do
    container_name=$(echo "$line" | awk -F': ' '{print $1}')
    health_status=$(echo "$line" | awk -F': ' '{print $2}')

    if [[ $health_status != *"(healthy)"* ]]; then
        echo "Container $container_name is not healthy: $health_status"
        unhealthy=true
        exit 1
    fi
done <<< "$container_statuses"

# Final check
if [ "$unhealthy" = false ]; then
    echo "All containers are healthy."
fi

ELASTICSEARCH_HOST="localhost"
ELASTICSEARCH_PORT="9200"

# Get list of all indexes
indexes=$(curl -sk -u "elastic:$elastic" "https://${ELASTICSEARCH_HOST}:${ELASTICSEARCH_PORT}/_cat/indices?v" | awk '{print $3}')

# Check if winlogbeat index exists
if echo "$indexes" | grep -q "winlogbeat"; then
    echo "Index 'winlogbeat' exists."
else
    echo "Index 'winlogbeat' does not exist." >&2
    exit 1
fi

# Check if we can query the winlogbeat index
response=$(curl -sk -u "elastic:$elastic"  "https://${ELASTICSEARCH_HOST}:${ELASTICSEARCH_PORT}/winlogbeat-*/_search" -H "Content-Type: application/json" -d '{
  "size": 1,
  "query": {
    "match_all": {}
  }
}')

# Check if the curl command was successful
if [ $? -eq 0 ]; then
  echo "Querying winlogbeat executed successfully."
else
  echo "Error executing the query of winlogbeat." >&2
  exit 1
fi

# Check the kibana saved objects.
# response=$(curl -sk -u "elastic:$elastic"  "https://${ELASTICSEARCH_HOST}:${ELASTICSEARCH_PORT}/.kibana/_search" -H "Content-Type: application/json" -d '{
#   "size": 1000,
#   "query": {
#     "term": {
#       "type": "dashboard"
#     }
#   }
# }')
# echo $response


response=$(curl -sk -u "elastic:$elastic"  "https://${ELASTICSEARCH_HOST}/api/kibana/management/saved_objects/_find?perPage=500&page=1&type=dashboard&sortField=updated_at&sortOrder=desc")

#!/bin/bash

# List of dashboard names to check
declare -a names_to_check=(
  "User Security"
  "User HR"
  "Sysmon Summary"
  "Security Dashboard - Security Log"
  "Process Explorer"
  "Computer Software Overview"
  "Alerting Dashboard"
  "HealthCheck Dashboard - Overview"
)

# Extract dashboard names from the JSON response stored in the variable
dashboard_names=$(echo "$response" | jq -r '.saved_objects[] | select(.type == "dashboard") | .meta.title')

# Check each name
for name in "${names_to_check[@]}"; do
  if grep -qF "$name" <<< "$dashboard_names"; then
    echo "Dashboard found: $name"
  else
    echo "Dashboard NOT found: $name" >&2
    exit 1
  fi
done
