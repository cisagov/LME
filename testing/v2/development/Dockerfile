# Base stage with common dependencies
FROM ubuntu:22.04 AS base
ARG USER_ID=1001
ARG GROUP_ID=1001

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    locales \
    ca-certificates \
    sudo \
    sshpass \
    openssh-client \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

RUN groupadd -g $GROUP_ID lme-user \
    && useradd -m -u $USER_ID -g lme-user --badnames lme-user \
    && usermod -aG sudo lme-user

RUN echo "lme-user ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

ENV BASE_DIR=/home/lme-user
WORKDIR $BASE_DIR

# Ubuntu stage with full dependencies
FROM base AS ubuntu

RUN apt-get update && apt-get install -y --no-install-recommends \
    systemd \
    systemd-sysv \
    lsb-release \
    python3 \
    python3-venv \
    python3-pip \
    zip \
    git \
    curl \
    wget \
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

# Configure systemd
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

CMD ["/lib/systemd/systemd"]

# Pipeline stage with minimal dependencies
FROM base AS pipeline

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3.10-venv \
    openssh-client \
    curl \
    && curl -sL https://aka.ms/InstallAzureCLIDeb | bash \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

USER lme-user
CMD ["sleep", "infinity"]