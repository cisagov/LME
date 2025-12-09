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
    response=$(curl -kL -s --user "elastic:${elastic}" \
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

set_fleet_values() {
  fingerprint=$(/nix/var/nix/profiles/default/bin/podman exec -w /usr/share/elasticsearch/config/certs/ca lme-elasticsearch cat ca.crt  | openssl x509 -nout -fingerprint -sha256 | cut -d "=" -f 2| tr -d : | head -n1)
  fleet_api_response=$(printf '{"fleet_server_hosts": ["%s"]}' "https://${IPVAR}:${FLEET_PORT}" | curl -kL -v --user "elastic:${elastic}" -XPUT "${HEADERS[@]}" "${LOCAL_KBN_URL}/api/fleet/settings" -d @-)

  echo "Fleet API Response:"
  echo "$fleet_api_response"

  printf '{"hosts": ["%s"]}' "https://${IPVAR}:9200" | curl -kL --silent --user "elastic:${elastic}" -XPUT "${HEADERS[@]}" "${LOCAL_KBN_URL}/api/fleet/outputs/fleet-default-output" -d @- | jq
  printf '{"ca_trusted_fingerprint": "%s"}' "${fingerprint}" | curl -kL --silent --user "elastic:${elastic}" -XPUT "${HEADERS[@]}" "${LOCAL_KBN_URL}/api/fleet/outputs/fleet-default-output" -d @- | jq
  printf '{"config_yaml": "%s"}' "ssl.verification_mode: certificate" | curl -kL --silent --user "elastic:${elastic}" -XPUT "${HEADERS[@]}" "${LOCAL_KBN_URL}/api/fleet/outputs/fleet-default-output" -d @- | jq
  policy_id=$(printf '{"name": "%s", "description": "%s", "namespace": "%s", "monitoring_enabled": ["logs","metrics"], "inactivity_timeout": 1209600}' "Endpoint Policy" "" "default" | curl -k --silent --user "elastic:${elastic}" -XPOST "${HEADERS[@]}" "${LOCAL_KBN_URL}/api/fleet/agent_policies?sys_monitoring=true" -d @- | jq -r '.item.id')
  echo "Policy ID: ${policy_id}"
  pkg_version=$(curl -kL --user "elastic:${elastic}" -XGET "${HEADERS[@]}" "${LOCAL_KBN_URL}/api/fleet/epm/packages/endpoint" -d : | jq -r '.item.version')
  printf "{\"name\": \"%s\", \"description\": \"%s\", \"namespace\": \"%s\", \"policy_id\": \"%s\", \"enabled\": %s, \"inputs\": [{\"enabled\": true, \"streams\": [], \"type\": \"ENDPOINT_INTEGRATION_CONFIG\", \"config\": {\"_config\": {\"value\": {\"type\": \"endpoint\", \"endpointConfig\": {\"preset\": \"EDRComplete\"}}}}}], \"package\": {\"name\": \"endpoint\", \"title\": \"Elastic Defend\", \"version\": \"${pkg_version}\"}}" "Elastic Defend" "" "default" "${policy_id}" "true" | curl -k --silent --user "elastic:${elastic}" -XPOST "${HEADERS[@]}" "${LOCAL_KBN_URL}/api/fleet/package_policies" -d @- | jq
}

#main:
source /opt/lme/lme-environment.env

# Set the secrets values and export them (source instead of execute)
set -a
. $SCRIPT_DIR/extract_secrets.sh -q 

wait_for_fleet

set_fleet_values