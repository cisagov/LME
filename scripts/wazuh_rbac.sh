#!/bin/bash
source /root/.profile
podman exec -it lme-wazuh-manager /var/ossec/bin/rbac_control change-password
