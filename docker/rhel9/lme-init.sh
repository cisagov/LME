#!/bin/bash

INIT_FLAG="/opt/.lme_initialized"

if [ ! -f "$INIT_FLAG" ]; then
    echo "Running first-time LME initialization..."
    rm -rf /opt/lme/lme-environment.env
    
    # Copy environment file if it doesn't exist

    . /root/LME/docker/rhel9/environment.sh    
     
    # Update IPVAR in the environment file with the passed HOST_IP
    if [ ! -z "$HOST_IP" ]; then
        echo "Using HOST_IP: $HOST_IP"
        export IPVAR=$HOST_IP
    else
        echo "Warning: HOST_IP not set, using default IPVAR value"
    fi
    
    cd /root/LME/
    export NON_INTERACTIVE=true
    export AUTO_CREATE_ENV=true
    export AUTO_IP=${IPVAR:-127.0.0.1}
    ./install.sh --debug
    
    # Create flag file to indicate initialization is complete
    touch "$INIT_FLAG"
    echo "First-time initialization complete."
else
    echo "LME already initialized, skipping first-time setup."
    systemctl disable lme-setup.service
    systemctl daemon-reload
fi 