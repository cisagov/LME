#!/usr/bin/env bash

# Uninstall Docker script for Ubuntu 22.04

# Function to safely remove a file
safe_remove() {
    if [ -e "$1" ]; then
        sudo rm -f "$1"
        echo "Removed: $1"
    else
        echo "File not found, skipping: $1"
    fi
}

# Stop the Docker daemon
sudo systemctl stop docker.service
sudo systemctl stop docker.socket

# Uninstall Docker Engine, CLI, Containerd, and Docker Compose
sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-ce-rootless-extras docker-buildx-plugin

# Remove Docker directories and files
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
sudo rm -rf /etc/docker
sudo rm -rf ~/.docker

# Remove the Docker repository
safe_remove /etc/apt/sources.list.d/docker.list

# Remove the Docker GPG key
safe_remove /etc/apt/keyrings/docker.gpg
safe_remove /usr/share/keyrings/docker-archive-keyring.gpg  # Check alternative location

# Update the package cache
sudo apt-get update

# Auto-remove any unused dependencies
sudo apt-get autoremove -y

echo "Docker has been uninstalled from your Ubuntu 22.04 system."
echo "You may need to reboot your system for all changes to take effect."