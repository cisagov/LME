#!/usr/bin/env bash
set -x

HEADERS=(
  -H "kbn-version: 8.12.2"
  -H "kbn-xsrf: kibana"
  -H 'Content-Type: application/json'
)

set_fleet_values() {
  fingerprint=$(/nix/var/nix/profiles/default/bin/podman exec -w /usr/share/elasticsearch/config/certs/ca lme-elasticsearch cat ca.crt  | openssl x509 -nout -fingerprint -sha256 | cut -d "=" -f 2| tr -d : | head -n1)
  printf '{"fleet_server_hosts": ["%s"]}' "https://${IPVAR}:${FLEET_PORT}" | curl -k --silent --user "${ELASTIC_USERNAME}:${ELASTICSEARCH_PASSWORD}" -XPUT "${HEADERS[@]}" "${LOCAL_KBN_URL}/api/fleet/settings" -d @- | jq
  printf '{"hosts": ["%s"]}' "https://${IPVAR}:9200" | curl -k --silent --user "${ELASTIC_USERNAME}:${ELASTICSEARCH_PASSWORD}" -XPUT "${HEADERS[@]}" "${LOCAL_KBN_URL}/api/fleet/outputs/fleet-default-output" -d @- | jq
  printf '{"ca_trusted_fingerprint": "%s"}' "${fingerprint}" | curl -k --silent --user "${ELASTIC_USERNAME}:${ELASTICSEARCH_PASSWORD}" -XPUT "${HEADERS[@]}" "${LOCAL_KBN_URL}/api/fleet/outputs/fleet-default-output" -d @- | jq
  printf '{"config_yaml": "%s"}' "ssl.verification_mode: certificate" | curl -k --silent --user "${ELASTIC_USERNAME}:${ELASTICSEARCH_PASSWORD}" -XPUT "${HEADERS[@]}" "${LOCAL_KBN_URL}/api/fleet/outputs/fleet-default-output" -d @- | jq
  policy_id=$(printf '{"name": "%s", "description": "%s", "namespace": "%s", "monitoring_enabled": ["logs","metrics"], "inactivity_timeout": 1209600}' "Endpoint Policy" "" "default" | curl -k --silent --user "${ELASTIC_USERNAME}:${ELASTICSEARCH_PASSWORD}" -XPOST "${HEADERS[@]}" "${LOCAL_KBN_URL}/api/fleet/agent_policies?sys_monitoring=true" -d @- | jq -r '.item.id')
  pkg_version=$(curl -k --user "${ELASTIC_USERNAME}:${ELASTICSEARCH_PASSWORD}" -XGET "${HEADERS[@]}" "${LOCAL_KBN_URL}/api/fleet/epm/packages/endpoint" -d : | jq -r '.item.version')
  printf "{\"name\": \"%s\", \"description\": \"%s\", \"namespace\": \"%s\", \"policy_id\": \"%s\", \"enabled\": %s, \"inputs\": [{\"enabled\": true, \"streams\": [], \"type\": \"ENDPOINT_INTEGRATION_CONFIG\", \"config\": {\"_config\": {\"value\": {\"type\": \"endpoint\", \"endpointConfig\": {\"preset\": \"EDRComplete\"}}}}}], \"package\": {\"name\": \"endpoint\", \"title\": \"Elastic Defend\", \"version\": \"${pkg_version}\"}}" "Elastic Defend" "" "default" "${policy_id}" "true" | curl -k --silent --user "${ELASTIC_USERNAME}:${ELASTICSEARCH_PASSWORD}" -XPOST "${HEADERS[@]}" "${LOCAL_KBN_URL}/api/fleet/package_policies" -d @- | jq
}

#main:
source /opt/lme/lme-environment.env
set_fleet_values
