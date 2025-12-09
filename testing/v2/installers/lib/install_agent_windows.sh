#!/usr/bin/env bash

# Default values
VERSION="8.18.8"
ARCHITECTURE="windows-x86_64"
HOST_IP="10.1.0.5"
CLIENT_IP="10.0.0.100"
USER="Test"
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
        --hostip)
            HOST_IP="$2"
            shift 2
            ;;
        --clientip)
            CLIENT_IP="$2"
            shift 2
            ;;
        --user)
            USER="$2"
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
echo "Downloading file"
curl -L -O "https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-${VERSION}-${ARCHITECTURE}.zip"

# Copy the file to windows
echo "Copying the file to windows..."
sshpass -e scp elastic-agent-${VERSION}-${ARCHITECTURE}.zip ${USER}@${CLIENT_IP}:elastic-agent-${VERSION}-${ARCHITECTURE}.zip

## Extract the archive
echo "Extracting windows archive..."
./run_elevated_powershell.sh "Expand-Archive -Path ./elastic-agent-${VERSION}-${ARCHITECTURE}.zip -Force"

## Install Elastic Agent with automatic "yes" response
echo "Installing elastic agent"
./run_elevated_powershell.sh "elastic-agent-8.18.8-windows-x86_64/elastic-agent-8.18.8-windows-x86_64/elastic-agent install --non-interactive --force --url=https://${HOST_IP}:$PORT --insecure --enrollment-token=${ENROLLMENT_TOKEN}"

echo "Waiting for service to start..."
sleep 60

echo "Checking agent service status"
./run_elevated_powershell.sh "Get-Service Elastic\` Agent"

#
## Enroll the Elastic Agent and capture the output
#enrollment_output=$(./run_elevated_powershell.sh "./elastic-agent-8.18.8-windows-x86_64/elastic-agent-8.18.8-windows-x86_64/elastic-agent enroll --force --insecure --url=https://${HOST_IP}:$PORT --enrollment-token=${ENROLLMENT_TOKEN} ")
#
## Check if enrollment was successful
#if echo "$enrollment_output" | grep -q "Successfully enrolled"; then
#    echo "Agent enrollment successful"
#else
#    echo "Agent enrollment failed"
#    echo "Enrollment output: $enrollment_output"
#    exit 1
#fi

## Restart the agent service
#sudo service elastic-agent restart
#
## Remove the downloaded archive
rm -f "elastic-agent-${VERSION}-${ARCHITECTURE}.zip"