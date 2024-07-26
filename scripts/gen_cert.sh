#!/usr/bin/env bash
source .env

#set via cli arg
CERT_DIR=${1:-caddy/certs}

## generate CA: 
echo "creating CA CRT"
export CERT_STRING='/C=US/ST=DC/L=Washington/O=CISA'
openssl genrsa -out ${CERT_DIR}/root-ca.key 4096
openssl req -new -key ${CERT_DIR}/root-ca.key -out ${CERT_DIR}/root-ca.csr -sha256 -subj "$CERT_STRING/CN=LME"
openssl x509 -req -days 3650 -in ${CERT_DIR}/root-ca.csr -signkey ${CERT_DIR}/root-ca.key -sha256 -out ${CERT_DIR}/root-ca.crt 

echo "creating caddy CRT"
openssl genrsa -out ${CERT_DIR}/caddy.key 4096
openssl req -new -key ${CERT_DIR}/caddy.key -out ${CERT_DIR}/caddy.csr -sha256 -subj "$CERT_STRING/CN=caddy"

#set openssl so that this cert can only perform server auth and cannot sign certs
{
	echo "[server]"
	echo "authorityKeyIdentifier=keyid,issuer"
	echo "basicConstraints = critical,CA:FALSE"
	echo "extendedKeyUsage=serverAuth,clientAuth"
	echo "keyUsage = critical, digitalSignature, keyEncipherment"
	#echo "subjectAltName = DNS:elasticsearch, IP:127.0.0.1"
	echo "subjectAltName = DNS:ls1, IP:127.0.0.1"
	echo "subjectKeyIdentifier=hash"
} >${CERT_DIR}/caddy.cnf
openssl x509 -req -days 3650 -in ${CERT_DIR}/caddy.csr -sha256 -CA ${CERT_DIR}/root-ca.crt -CAkey ${CERT_DIR}/root-ca.key -CAcreateserial -out ${CERT_DIR}/caddy.crt -extfile ${CERT_DIR}/caddy.cnf -extensions server
