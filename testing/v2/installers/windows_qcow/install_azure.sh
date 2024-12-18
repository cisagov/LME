#!/usr/bin/env bash

echo "Installing Azure CLI..."

# Install prerequisites
sudo apt-get update
sudo apt-get install -y ca-certificates curl apt-transport-https lsb-release gnupg sshpass

# Download and install the Microsoft signing key
sudo mkdir -p /etc/apt/keyrings
curl -sLS https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/microsoft.gpg > /dev/null

# Add the Azure CLI software repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/azure-cli.list

# Update repository information and install Azure CLI
sudo apt-get update
sudo apt-get install -y azure-cli
