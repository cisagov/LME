#!/bin/bash

INIT_FLAG="/opt/.lme_initialized"

if [ ! -f "$INIT_FLAG" ]; then
    echo "Running first-time LME initialization..."
    
    # Copy environment file if it doesn't exist
    cp -n /LME/config/example.env /LME/config/lme-environment.env
    
    # Run initial setup with timing
    cd /LME/ansible/
    echo "Starting system setup at $(date)"
    # time ansible-playbook install_lme_local.yml --tags system -e "clone_dir=/LME"
    time ansible-playbook install_lme_local.yml  -e "clone_dir=/LME"
    echo "Starting post-install setup at $(date)"
    time ansible-playbook post_install_local.yml -e "debug_mode=true" -e "clone_dir=/LME"
    echo "Setup completed at $(date)"
    
    # Create flag file to indicate initialization is complete
    touch "$INIT_FLAG"
    echo "First-time initialization complete."
else
    echo "LME already initialized, skipping first-time setup."
    systemctl disable lme-setup.service
    systemctl daemon-reload
fi 
