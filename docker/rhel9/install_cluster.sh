#!/bin/bash

# LME Docker RHEL9 Cluster Install Script
# Run from host while docker-compose-cluster.yml containers are running.
# This sets up SSH between cluster containers and runs Ansible for cluster install.
#
# Uses lme-user (with passwordless sudo) for SSH between nodes, matching the
# Ubuntu cluster install approach.
# Shared logic: ../lib/install_cluster_rhel_common.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MASTER_CONTAINER="lme_rhel9_cluster_node1"
NODE2_CONTAINER="lme_rhel9_cluster_node2"
NODE3_CONTAINER="lme_rhel9_cluster_node3"
LME_CLUSTER_LABEL="RHEL9"
# eth0-only IP; no removal of /opt/lme/lme-environment.env (matches prior rhel9 script)
LME_CLUSTER_ENV_PROFILE="simple"

source "${SCRIPT_DIR}/../lib/install_cluster_rhel_common.sh"
