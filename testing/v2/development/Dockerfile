# Use Ubuntu 22.04 with systemd as base image
FROM jrei/systemd-ubuntu:22.04
ARG USER_ID=1001
ARG GROUP_ID=1001

# Set environment variable to avoid interactive dialogues during build
ENV DEBIAN_FRONTEND=noninteractive

# Set up locale
RUN apt-get update && apt-get install -y locales && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

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
    && rm -rf /var/lib/apt/lists/* \
    && curl -sL https://aka.ms/InstallAzureCLIDeb | bash \
    && wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt install -y ./google-chrome-stable_current_amd64.deb \
    && rm -rf google-chrome-stable_current_amd64.deb \
    && sudo apt-get install -f \
    && apt-get clean

# Install Ansible
# RUN python3 -m pip install --upgrade pip \
#     && python3 -m pip install ansible

# Create a user and group 'admin.ackbar' with GID 1001
RUN groupadd -g $GROUP_ID admin.ackbar \
    && useradd -m -u $USER_ID -g admin.ackbar --badnames admin.ackbar \
    && usermod -aG sudo admin.ackbar

# Allow 'admin.ackbar' user to run sudo commands without a password
RUN echo "admin.ackbar ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Define the base directory as an environment variable
ENV BASE_DIR=/home/admin.ackbar

# Set work directory
WORKDIR $BASE_DIR

# Set timezone (optional)
ENV TZ=America/New_York

# Create an entrypoint script
RUN echo '#!/bin/bash\n\
if [ "$1" = "systemd.unit=multi-user.target" ]; then\n\
  exec /lib/systemd/systemd "$@"\n\
elif [ "$(id -u)" -eq 0 ]; then\n\
  exec sudo -u admin.ackbar "$@"\n\
else\n\
  exec "$@"\n\
fi' > /entrypoint.sh \
    && chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["systemd.unit=multi-user.target"]