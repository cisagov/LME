#!/bin/bash
set -e  # Exit on any error

SYSTEMD_FLAG="/opt/.systemd_mounted"

if [ ! -f "$SYSTEMD_FLAG" ]; then
    echo "Reinstalling systemd to populate mounted volumes..."
    
    # Force a complete reinstall of systemd packages
    apt-get update
    apt-get install --reinstall -y systemd systemd-sysv
    apt-get clean && rm -rf /var/lib/apt/lists/*

    # Clean up systemd
    cd /lib/systemd/system/sysinit.target.wants/ && \
        ls | grep -v systemd-tmpfiles-setup | xargs rm -f $1
    rm -f /lib/systemd/system/multi-user.target.wants/*
    rm -f /etc/systemd/system/*.wants/*
    rm -f /lib/systemd/system/local-fs.target.wants/*
    rm -f /lib/systemd/system/sockets.target.wants/*udev*
    rm -f /lib/systemd/system/sockets.target.wants/*initctl*
    rm -f /lib/systemd/system/basic.target.wants/*
    rm -f /lib/systemd/system/anaconda.target.wants/*

    # Configure systemd-logind
    mkdir -p /etc/systemd/system/systemd-logind.service.d
    echo -e "[Service]\nProtectHostname=no" > /etc/systemd/system/systemd-logind.service.d/override.conf

    # Create flag file to indicate systemd is mounted
    touch "$SYSTEMD_FLAG"
    
    # Exit with special code to trigger restart
    cp /LME/docker/lme-setup.service /etc/systemd/system/lme-setup.service
    #tail -f /dev/null
    exit 0
else
    # If systemd is already installed in mounted volumes, start it
    exec /lib/systemd/systemd --system
fi