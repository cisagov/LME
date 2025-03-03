#!/bin/bash

# Check if IP0 is set
if [ -z "$IP0" ]; then
    echo "Error: IP0 is not set. Please set it before running this script."
    exit 1
fi

# Check if the file exists
ENV_FILE="config/lme-environment.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: $ENV_FILE does not exist."
    exit 1
fi

# Perform the substitutions
sed -i \
    -e "s/IPVAR=127.0.0.1/IPVAR=$IP0/" \
    -e 's|LOCAL_KBN_URL=https://127.0.0.1:5601|LOCAL_KBN_URL=https://lme-kibana:5601|' \
    -e 's|LOCAL_ES_URL=https://127.0.0.1:9200|LOCAL_ES_URL=https://lme-elasticsearch:9200|' \
    "$ENV_FILE"
    #-e "s|LOCAL_KBN_URL=https://127.0.0.1:5601|LOCAL_KBN_URL=https://$IP0:5601|" \
    #-e "s|LOCAL_ES_URL=https://127.0.0.1:9200|LOCAL_ES_URL=https://$IP0:9200|" \

echo "Substitutions completed in $ENV_FILE"

# Optional: Display the changed lines
echo "Changed lines:"
grep -E "IPVAR=|LOCAL_KBN_URL=|LOCAL_ES_URL=" "$ENV_FILE"