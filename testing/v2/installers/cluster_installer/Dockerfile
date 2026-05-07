FROM ubuntu:24.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    jq \
    sshpass \
    git \
    curl \
    openssh-client \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
# The script changes to INSTALLERS_DIR which is parent of cluster_installer
WORKDIR /workspace/testing/v2/installers

# Copy the installers directory structure
# Build context should be the LME repo root
COPY testing/v2/installers/ /workspace/testing/v2/installers/

# Make the script executable
RUN chmod +x /workspace/testing/v2/installers/cluster_installer/setup_cluster.sh

# Default command
CMD ["/bin/bash"]
