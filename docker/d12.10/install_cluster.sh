#!/bin/bash

# LME Docker Debian 12.10 Cluster Install Script
# Run from host while docker-compose-cluster.yml containers are running.
# This sets up SSH between cluster containers and runs Ansible for cluster install.
#
# Uses lme-user (with passwordless sudo) for SSH between nodes.
# Shared logic: ../lib/install_cluster_debian_common.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MASTER_CONTAINER="lme_d1210_cluster_node1"
NODE2_CONTAINER="lme_d1210_cluster_node2"
NODE3_CONTAINER="lme_d1210_cluster_node3"
LME_CLUSTER_LABEL="Debian 12.10"

source "${SCRIPT_DIR}/../lib/install_cluster_debian_common.sh"
