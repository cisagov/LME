#!/bin/bash

# LME Docker Rocky Linux 9 Cluster Install Script
# Run from host while docker-compose-cluster.yml containers are running.
# This sets up SSH between cluster containers and runs Ansible for cluster install.
#
# Uses lme-user (with passwordless sudo) for SSH between nodes, matching the
# Ubuntu cluster install approach.
# Shared logic: ../lib/install_cluster_rhel_common.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MASTER_CONTAINER="lme_rocky9_cluster_node1"
NODE2_CONTAINER="lme_rocky9_cluster_node2"
NODE3_CONTAINER="lme_rocky9_cluster_node3"
LME_CLUSTER_LABEL="Rocky Linux 9"
# Extended master IP detection + remove stale /opt/lme/lme-environment.env before install
LME_CLUSTER_ENV_PROFILE="extended"

source "${SCRIPT_DIR}/../lib/install_cluster_rhel_common.sh"
