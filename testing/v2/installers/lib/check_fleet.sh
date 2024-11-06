#!/usr/bin/env bash

set -e
#set -x

echo "LME Diagnostic Script"
echo "====================="

# ... [previous parts of the script remain unchanged] ...

# 8. Check Elasticsearch logs
echo "Checking Elasticsearch logs (last 20 lines)..."
if /nix/var/nix/profiles/default/bin/podman logs lme-elasticsearch 2>/dev/null | tail -n 20; then
    echo "Elasticsearch logs retrieved successfully."
else
    echo "Error retrieving Elasticsearch logs. Check if the container is running."
fi

# 9. Check Kibana logs
echo "Checking Kibana logs (last 20 lines)..."
if /nix/var/nix/profiles/default/bin/podman logs lme-kibana 2>/dev/null | tail -n 20; then
    echo "Kibana logs retrieved successfully."
else
    echo "Error retrieving Kibana logs. Check if the container is running."
fi

# 10. Check locale settings
echo "Checking locale settings..."
locale
echo "LANG=$LANG"
echo "LANGUAGE=$LANGUAGE"
echo "LC_ALL=$LC_ALL"

# 11. Check if locale-gen is available and list available locales
echo "Checking available locales..."
if command -v locale-gen > /dev/null; then
    locale -a
else
    echo "locale-gen command not found. Unable to list available locales."
fi

echo "Diagnostic script completed."