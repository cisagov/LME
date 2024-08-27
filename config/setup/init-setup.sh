#!/bin/bash
set -euo pipefail

if [[ -z "${ELASTIC_PASSWORD:-}" || -z "${KIBANA_PASSWORD:-}" ]]; then
  echo "ERROR: ELASTIC_PASSWORD and/or KIBANA_PASSWORD are missing."
  exit 1
fi

CONFIG_DIR="/usr/share/elasticsearch/config"
CERTS_DIR="${CONFIG_DIR}/certs"
INSTANCES_PATH="${CONFIG_DIR}/setup/instances.yml"

if [ ! -f "${CERTS_DIR}/ca.zip" ]; then
  echo "Creating CA..."
  elasticsearch-certutil ca --silent --pem --out "${CERTS_DIR}/ca.zip"
  unzip -o "${CERTS_DIR}/ca.zip" -d "${CERTS_DIR}"
fi

if [ ! -f "${CERTS_DIR}/certs.zip" ]; then
  echo "Creating certificates..."
  elasticsearch-certutil cert --silent --pem --in "${INSTANCES_PATH}" --out "${CERTS_DIR}/certs.zip" --ca-cert "${CERTS_DIR}/ca/ca.crt" --ca-key "${CERTS_DIR}/ca/ca.key"
  unzip -o "${CERTS_DIR}/certs.zip" -d "${CERTS_DIR}"
  cat "${CERTS_DIR}/elasticsearch/elasticsearch.crt" "${CERTS_DIR}/ca/ca.crt" > "${CERTS_DIR}/elasticsearch/elasticsearch.chain.pem"
fi

echo "Setting file permissions..."
chown -R root:root "${CERTS_DIR}"
find "${CERTS_DIR}" -type d -exec chmod 754 {} \;
find "${CERTS_DIR}" -type f -exec chmod 644 {} \;
