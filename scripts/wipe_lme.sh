#!/bin/bash
# Fully uninstall LME: stop services, remove containers, volumes, images, and config.
# Safe to run before a fresh install.

set -e

echo "Stopping all LME services..."
sudo systemctl stop lme* 2>/dev/null || true

echo "Stopping and removing all containers..."
sudo -i podman stop -a 2>/dev/null || true
sudo -i podman rm -af 2>/dev/null || true

echo "Removing volumes, secrets, and images..."
sudo -i podman volume rm -a 2>/dev/null || true
sudo -i podman secret rm -a 2>/dev/null || true
sudo -i podman image prune -af 2>/dev/null || true

echo "Removing LME quadlet and systemd unit files..."
sudo rm -f /etc/containers/systemd/lme-*.container
sudo rm -f /etc/containers/systemd/lme-*.volume
sudo rm -f /etc/containers/systemd/lme.network
sudo rm -f /etc/containers/systemd/lme.service
sudo rm -f /etc/containers/networks/lme.json
sudo rm -f /etc/systemd/system/lme-*.service
sudo rm -f /etc/systemd/system/lme-*.path
sudo rm -f /etc/systemd/system/lme.service

echo "Reloading systemd and clearing failed states..."
sudo systemctl daemon-reload
sudo systemctl reset-failed

echo "Removing /opt/lme..."
sudo rm -rf /opt/lme

echo "Cleaning up container config..."
rm -rf ~/.config/containers
sudo rm -f /etc/containers/storage.conf

echo "Wipe complete. Ready for fresh install."
