#!/bin/bash

# Find the latest podman version in the Nix store
latest_podman=$(find /nix/store -maxdepth 1 -name '*-podman-*' | 
                sed -n 's/.*-podman-\([0-9.]*\)$/\1/p' | 
                sort -V | 
                tail -n1)

if [ -n "$latest_podman" ]; then
    # Find the full path of the latest version
    podman_path=$(find /nix/store -maxdepth 1 -name "*-podman-${latest_podman}")
    
    # Assign the result to a variable
    LATEST_PODMAN_PATH="$podman_path"
    
    echo "Latest Podman version found: $latest_podman"
    echo "Path: $LATEST_PODMAN_PATH"
else
    echo "No Podman installation found in the Nix store."
fi


sudo ln -sf "$LATEST_PODMAN_PATH/lib/systemd/system-generators/podman-system-generator" /usr/lib/systemd/system-generators/podman-system-generator
sudo ln -sf "$LATEST_PODMAN_PATH/lib/systemd/user-generators/podman-user-generator" /usr/lib/systemd/user-generators/
sudo ln -sf -t /usr/lib/systemd/system/ /nix/store/$LATEST_PODMAN_PATH/lib/systemd/system/*
sudo ln -sf -t /usr/lib/systemd/user/ /nix/store/$LATEST_PODMAN_PATH/lib/systemd/user/*

echo "Linked the files in systemd"

