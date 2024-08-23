#!/bin/bash

# Script to remove Docker volumes

# Function to check if Docker is installed
check_docker_installed() {
    if ! command -v docker &> /dev/null; then
        echo "Error: Docker is not installed on this system."
        exit 1
    fi
}

# Function to check if Docker daemon is running
check_docker_running() {
    if ! docker info &> /dev/null; then
        echo "Error: Docker daemon is not running."
        exit 1
    fi
}

# Function to remove all Docker volumes
remove_docker_volumes() {
    echo "Removing all Docker volumes..."
    
    # List all volumes
    volumes=$(docker volume ls -q)
    
    if [ -z "$volumes" ]; then
        echo "No Docker volumes found."
    else
        # Remove each volume
        for volume in $volumes; do
            echo "Removing volume: $volume"
            docker volume rm "$volume"
        done
        echo "All Docker volumes have been removed."
    fi
}

# Main execution
echo "Docker Volume Removal Script"
echo "============================"

# Check if Docker is installed
check_docker_installed

# Check if Docker daemon is running
check_docker_running

# Check for -y flag
if [[ "$1" == "-y" ]]; then
    remove_docker_volumes
else
    # Prompt for confirmation
    read -p "Are you sure you want to remove all Docker volumes? This action cannot be undone. (y/n): " confirm

    if [[ $confirm == [Yy]* ]]; then
        remove_docker_volumes
    else
        echo "Operation cancelled. No volumes were removed."
    fi
fi

echo "Script completed."