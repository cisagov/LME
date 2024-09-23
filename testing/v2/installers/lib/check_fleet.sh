#!/usr/bin/env bash

set -e
set -x

echo "LME Diagnostic Script"
echo "====================="

# 1. Check environment variables
echo "Checking environment variables..."
source /opt/lme/lme-environment.env
echo "IPVAR: $IPVAR"
echo "FLEET_PORT: $FLEET_PORT"
echo "ELASTIC_USERNAME: $ELASTIC_USERNAME"
echo "ELASTICSEARCH_PASSWORD: $ELASTICSEARCH_PASSWORD"
echo "LOCAL_KBN_URL: $LOCAL_KBN_URL"
echo "LOCAL_ES_URL: $LOCAL_ES_URL"
echo "STACK_VERSION: $STACK_VERSION"

# 2. Check if required commands are available
echo "Checking required commands..."
command -v curl >/dev/null 2>&1 || { echo "curl is not installed"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is not installed"; exit 1; }
command -v openssl >/dev/null 2>&1 || { echo "openssl is not installed"; exit 1; }

# 3. Test Elasticsearch connectivity
echo "Testing Elasticsearch connectivity..."
curl -k -v --user "${ELASTIC_USERNAME}:${ELASTICSEARCH_PASSWORD}" "${LOCAL_ES_URL}"

# 4. Test Kibana connectivity
echo "Testing Kibana connectivity..."
curl -k -v --user "${ELASTIC_USERNAME}:${ELASTICSEARCH_PASSWORD}" "${LOCAL_KBN_URL}/api/status"

# 5. Check Elasticsearch certificate
echo "Checking Elasticsearch certificate..."
/nix/var/nix/profiles/default/bin/podman exec -w /usr/share/elasticsearch/config/certs/ca lme-elasticsearch cat ca.crt | openssl x509 -text -noout

# 6. Test Fleet API
echo "Testing Fleet API..."
curl -k -v --user "${ELASTIC_USERNAME}:${ELASTICSEARCH_PASSWORD}" \
  -H "kbn-version: ${STACK_VERSION}" \
  -H "kbn-xsrf: kibana" \
  -H 'Content-Type: application/json' \
  "${LOCAL_KBN_URL}/api/fleet/settings"

# 7. Check Podman containers
echo "Checking Podman containers..."
/nix/var/nix/profiles/default/bin/podman ps -a

# 8. Check Elasticsearch logs
echo "Checking Elasticsearch logs (last 20 lines)..."
/nix/var/nix/profiles/default/bin/podman logs lme-elasticsearch --tail 20

# 9. Check Kibana logs
echo "Checking Kibana logs (last 20 lines)..."
/nix/var/nix/profiles/default/bin/podman logs lme-kibana --tail 20

echo "Diagnostic script completed."