#!/usr/bin/env bash
source .env
USER=elastic
PASSWORD=${ELASTIC_PASSWORD_ESCAPED}
PROTO=https

#TODO: make this a cli flag
#------------ edit this-----------
#assumes files are INDEX_mapping.json + INDEX.json
# mapping + logs
DIR=/data/alerts/
INDICES=$(ls ${DIR} | cut -f -3 -d '.' | grep -v "_mapping"| grep -v "template"| sort | uniq)

#------------ edit this -----------

echo -e "\n\ncheck \`podman logs -f CONTAINER_NAME\` for verbose output\n\n"
echo -e "\n--Uploading: --\n"
for x in ${INDICES};
do
  echo "podman runs for $x:"
  podman run  -it -d -v ${DIR}${x}_mapping.json:/tmp/data.json -e NODE_TLS_REJECT_UNAUTHORIZED=0 --userns="" --network=host  elasticdump/elasticsearch-dump   --input=/tmp/data.json   --output=${PROTO}://${USER}:${PASSWORD}@localhost:9200/${x}  --type=mapping

  podman run  -it -d -v ${DIR}${x}.json:/tmp/data.json -e NODE_TLS_REJECT_UNAUTHORIZED=0 --userns="" --network=host  elasticdump/elasticsearch-dump   --input=/tmp/data.json --output=${PROTO}://${USER}:${PASSWORD}@localhost:9200/${x} --limit=5000
  echo ""
done

## cleanup: 
echo "--to cleanup when done:--"
echo "podman ps -a  --format \"{{.Image}} {{.Names}}\" | grep -i "elasticdump" | awk \'{print $2}\' | xargs podman rm"

tot=$(wc -l $(ls ${DIR} | grep -v "_mapping" | xargs -I{} echo ${DIR}{}))
echo -e "\n--Expected Log #:\n $tot--"

