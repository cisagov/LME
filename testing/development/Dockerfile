# Use Ubuntu 22.04 as base image
FROM ubuntu:22.04

# Set environment variable to avoid interactive dialogues during build
ENV DEBIAN_FRONTEND=noninteractive

# Install necessary APT packages including Python and pip
RUN apt-get update && apt-get install -y \
    lsb-release \
    python3 \
    python3-venv \
    python3-pip \
    zip \
    git \
    curl \
    wget \
    sudo \
    && wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb" \
    && dpkg -i packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y powershell \
    && rm -rf /var/lib/apt/lists/* \
    && curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Create a user and group 'admin.ackbar' with GID 1001
RUN groupadd -g 1001 admin.ackbar \
    && useradd -m -u 1001 -g admin.ackbar --badnames admin.ackbar \
    && usermod -aG sudo admin.ackbar

# Allow 'admin.ackbar' user to run sudo commands without a password
RUN echo "admin.ackbar ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Define the base directory as an environment variable
ENV BASE_DIR=/home/admin.ackbar/LME

# Set work directory
WORKDIR $BASE_DIR

# Change to non-root privilege
USER admin.ackbar

# Set timezone (optional)
ENV TZ=America/New_York

# Keep the container running (This can be replaced by your application's main process)
CMD ["tail", "-f", "/dev/null"]