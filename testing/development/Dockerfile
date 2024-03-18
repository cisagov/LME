# Use Ubuntu 22.04 as base image
FROM ubuntu:22.04
ARG USER_ID=1001
ARG GROUP_ID=1001

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
    freerdp2-x11 \
    pkg-config \
    libcairo2-dev \
    libdbus-1-dev \
    distro-info \
    libgirepository1.0-dev \
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



# Create a user and group 'admin.ackbar' with GID 1001
RUN groupadd -g $GROUP_ID admin.ackbar \
    && useradd -m -u $USER_ID -g admin.ackbar --badnames admin.ackbar \
    && usermod -aG sudo admin.ackbar

# Allow 'admin.ackbar' user to run sudo commands without a password
RUN echo "admin.ackbar ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Define the base directory as an environment variable
ENV BASE_DIR=/home/admin.ackbar/LME

# Set work directory
WORKDIR $BASE_DIR

# Change to non-root privilege
# USER admin.ackbar

# Set timezone (optional)
ENV TZ=America/New_York

# Keep the container running (This can be replaced by your application's main process)
CMD ["tail", "-f", "/dev/null"]