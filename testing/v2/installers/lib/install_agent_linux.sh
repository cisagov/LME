#!/usr/bin/env bash

# Default values
VERSION="8.18.8"
ARCHITECTURE="linux-x86_64"
IP="10.1.0.5"
PORT="8220"
ENROLLMENT_TOKEN=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            VERSION="$2"
            shift 2
            ;;
        --arch)
            ARCHITECTURE="$2"
            shift 2
            ;;
        --ip)
            IP="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --token)
            ENROLLMENT_TOKEN="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Download Elastic Agent
curl -L -s -O "https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-${VERSION}-${ARCHITECTURE}.tar.gz"

# Extract the archive
tar xzf "elastic-agent-${VERSION}-${ARCHITECTURE}.tar.gz"

# Change to the extracted directory
cd "elastic-agent-${VERSION}-${ARCHITECTURE}"

# Install Elastic Agent with automatic "yes" response
sudo ./elastic-agent install --non-interactive 

# Enroll the Elastic Agent and capture the output
enrollment_output=$(sudo /opt/Elastic/Agent/elastic-agent enroll -f --insecure --url=https://${IP}:$PORT --enrollment-token="${ENROLLMENT_TOKEN}" 2>&1)

# Check if enrollment was successful
if echo "$enrollment_output" | grep -q "Successfully enrolled"; then
    echo "Agent enrollment successful"
else
    echo "Agent enrollment failed"
    echo "Enrollment output: $enrollment_output"
    exit 1
fi

# Restart the agent service
sudo service elastic-agent restart

# Remove the downloaded archive
cd ..
rm -f "elastic-agent-${VERSION}-${ARCHITECTURE}.tar.gz"
