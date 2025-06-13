#!/bin/bash
# Script to run all Docker containers in the workflow

echo "Starting build-22-04..."
sudo act --bind --workflows .github/workflows/docker.yml --job build-22-04 --secret-file .env

echo "Starting build-24-04..."
sudo act --bind --workflows .github/workflows/docker.yml --job build-24-04 --secret-file .env

echo "Starting build-d12-10..."
sudo act --bind --workflows .github/workflows/docker.yml --job build-d12-10 --secret-file .env

echo "All jobs completed." 