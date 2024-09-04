# Use Ubuntu 22.04 as base image
FROM ubuntu:22.04
ARG USER_ID=1001
ARG GROUP_ID=1001

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Set up locale
RUN apt-get update && apt-get install -y locales && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# Install systemd and other necessary packages
RUN apt-get update && apt-get install -y systemd systemd-sysv \
    lsb-release \
    python3 \
    python3-venv \
    python3-pip \
    zip \
    git \
    curl \
    wget \
    sudo \
    cron \
    freerdp2-x11 \
    pkg-config \
    libcairo2-dev \
    libdbus-1-dev \
    distro-info \
    libgirepository1.0-dev \
    ansible \
    && wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb" \
    && dpkg -i packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y powershell \
    && curl -sL https://aka.ms/InstallAzureCLIDeb | bash \
    && wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt install -y ./google-chrome-stable_current_amd64.deb \
    && rm -rf google-chrome-stable_current_amd64.deb \
    && apt-get install -f \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create a user and group 'lme-user' with specified GID
RUN groupadd -g $GROUP_ID lme-user \
    && useradd -m -u $USER_ID -g lme-user --badnames lme-user \
    && usermod -aG sudo lme-user

# Allow 'lme-user' user to run sudo commands without a password
RUN echo "lme-user ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Define the base directory as an environment variable
ENV BASE_DIR=/home/lme-user

# Set work directory
WORKDIR $BASE_DIR

# Set timezone (optional)
ENV TZ=America/New_York

# Ensure systemd is installed and configured properly
RUN cd /lib/systemd/system/sysinit.target.wants/ && \
    ls | grep -v systemd-tmpfiles-setup | xargs rm -f $1 && \
    rm -f /lib/systemd/system/multi-user.target.wants/* && \
    rm -f /etc/systemd/system/*.wants/* && \
    rm -f /lib/systemd/system/local-fs.target.wants/* && \
    rm -f /lib/systemd/system/sockets.target.wants/*udev* && \
    rm -f /lib/systemd/system/sockets.target.wants/*initctl* && \
    rm -f /lib/systemd/system/basic.target.wants/* && \
    rm -f /lib/systemd/system/anaconda.target.wants/* && \
    mkdir -p /etc/systemd/system/systemd-logind.service.d && \
    echo -e "[Service]\nProtectHostname=no" > /etc/systemd/system/systemd-logind.service.d/override.conf

# Create a script to set locale on container start
RUN echo '#!/bin/bash\n\
export LANG=en_US.UTF-8\n\
export LANGUAGE=en_US:en\n\
export LC_ALL=en_US.UTF-8\n\
exec "$@"' > /usr/local/bin/entrypoint.sh && \
    chmod +x /usr/local/bin/entrypoint.sh

# Use the entrypoint script
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Use systemd as the init system
CMD ["/lib/systemd/systemd"]