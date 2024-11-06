#!/bin/bash
set -euo pipefail

CONFIG_DIR="/usr/share/elasticsearch/config"
CERTS_DIR="${CONFIG_DIR}/certs"
INSTANCES_PATH="${CONFIG_DIR}/setup/instances.yml"

if [[ -z "${ELASTIC_PASSWORD:-}" || -z "${KIBANA_PASSWORD:-}" ]]; then
  echo "ERROR: ELASTIC_PASSWORD and/or KIBANA_PASSWORD are missing."
  exit 1
fi

if [ ! -f "${CERTS_DIR}/ACCOUNTS_CREATED" ]; then
  echo "Waiting for Elasticsearch availability";
  until curl -s --cacert config/certs/ca/ca.crt https://lme-elasticsearch:9200 | grep -q "missing authentication credentials"; do echo "WAITING"; sleep 30; done;

  echo "Setting kibana_system password";
  until curl -L -s -X POST --cacert config/certs/ca/ca.crt -u elastic:${ELASTIC_PASSWORD} -H "Content-Type: application/json" https://lme-elasticsearch:9200/_security/user/kibana_system/_password -d "{\"password\":\"${KIBANA_PASSWORD}\"}" | grep -q "^{}"; do sleep 2; done;

  echo "All done!" | tee "${CERTS_DIR}/ACCOUNTS_CREATED" ;
fi
echo "Accounts kibana_system Created!"
