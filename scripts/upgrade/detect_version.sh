#!/bin/bash

# detect_version.sh - Script to detect current LME version and determine if an upgrade is needed

set -e

ENV_FILE="/opt/lme/lme-environment.env"
CURRENT_DIR=$(dirname "$(readlink -f "$0")")
REPO_DIR=$(realpath "$CURRENT_DIR/../../")
VERSION_FILE="$REPO_DIR/version.txt"

# Check if version file exists
if [ ! -f "$VERSION_FILE" ]; then
    echo "Version file not found at $VERSION_FILE"
    echo "This suggests the LME repository is not properly cloned or the version file is missing."
    exit 1
fi

# Read latest version from file
LATEST_VERSION=$(cat "$VERSION_FILE")

# Check if environment file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "LME environment file not found at $ENV_FILE"
    echo "This suggests LME is not currently installed or the environment file is missing."
    exit 1
fi

# Check if version is defined in environment file
if grep -q "^LME_VERSION=" "$ENV_FILE"; then
    # Extract current version
    CURRENT_VERSION=$(grep "^LME_VERSION=" "$ENV_FILE" | cut -d'=' -f2)
    echo "Current LME version: $CURRENT_VERSION"
    
    # Compare versions (simple string comparison for now)
    if [ "$CURRENT_VERSION" != "$LATEST_VERSION" ]; then
        echo "Upgrade needed: $CURRENT_VERSION -> $LATEST_VERSION"
        UPGRADE_NEEDED=true
    else
        echo "LME is already at the latest version ($LATEST_VERSION)"
        UPGRADE_NEEDED=false
    fi
else
    echo "LME_VERSION not found in environment file"
    echo "This suggests an older version of LME without version tracking"
    echo "Upgrade needed: Unknown -> $LATEST_VERSION"
    UPGRADE_NEEDED=true
    
    # Add version to environment file
    echo "Adding LME_VERSION=$LATEST_VERSION to environment file"
    echo "LME_VERSION=$LATEST_VERSION" >> "$ENV_FILE"
fi

# Check container versions
echo "Checking container versions..."
ES_VERSION=$(grep "^STACK_VERSION=" "$ENV_FILE" | cut -d'=' -f2)
echo "Current Elasticsearch version: $ES_VERSION"

# Output a summary
if [ "$UPGRADE_NEEDED" = true ]; then
    echo "========================================"
    echo "LME UPGRADE RECOMMENDED"
    echo "========================================"
    echo "Run the following command to upgrade:"
    echo "cd $REPO_DIR/ansible && ansible-playbook upgrade_lme.yml"
    exit 100  # Exit with code indicating upgrade needed
else
    echo "========================================"
    echo "LME IS UP TO DATE"
    echo "========================================"
    exit 0    # Exit with code indicating no upgrade needed
fi 