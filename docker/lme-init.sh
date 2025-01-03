#!/bin/bash

INIT_FLAG="/opt/.lme_initialized"

if [ ! -f "$INIT_FLAG" ]; then
    echo "Running first-time LME initialization..."
    
    # Copy environment file if it doesn't exist
    cp -n /root/LME/config/example.env /root/LME/config/lme-environment.env
    
    # Run initial setup
    cd /root/LME/ansible/
    ansible-playbook install_lme_local.yml --tags system
    ansible-playbook post_install_local.yml -e "debug_mode=true"
    
    # Create flag file to indicate initialization is complete
    touch "$INIT_FLAG"
    echo "First-time initialization complete."
else
    echo "LME already initialized, skipping first-time setup."
    systemctl disable lme-setup.service
    systemctl daemon-reload
fi 