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

# Red Hat stage with RHEL9/UBI9 base
FROM registry.access.redhat.com/ubi9/ubi:9.6 AS rhel-base

ARG USER_ID=1001
ARG GROUP_ID=1001

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

RUN dnf update -y && dnf install -y \
    glibc-langpack-en sudo openssh-clients sshpass \
    && dnf clean all \
    && while getent group $GROUP_ID > /dev/null 2>&1; do GROUP_ID=$((GROUP_ID + 1)); done \
    && while getent passwd $USER_ID > /dev/null 2>&1; do USER_ID=$((USER_ID + 1)); done \
    && groupadd -g $GROUP_ID lme-user \
    && useradd -m -u $USER_ID -g lme-user lme-user \
    && usermod -aG wheel lme-user \
    && echo "lme-user ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers \
    && echo "Defaults:lme-user !requiretty" >> /etc/sudoers

ENV BASE_DIR=/home/lme-user
WORKDIR $BASE_DIR

# Red Hat stage with full dependencies
FROM rhel-base AS rhel

RUN dnf install -y \
    systemd systemd-sysv \
    && dnf clean all

# Install EPEL repository
RUN dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm \
    && /usr/bin/crb enable \
    && dnf clean all

# Install development tools and dependencies
RUN dnf install -y \
    python3 \
    python3-pip \
    zip \
    git \
    curl \
    wget \
    cron \
    vim \
    freerdp \
    pkg-config \
    cairo-devel \
    dbus-devel \
    && dnf clean all

# Install PowerShell for RHEL
RUN curl -sSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/pki/rpm-gpg/microsoft.asc.gpg > /dev/null \
    && echo -e "[packages-microsoft-com-prod]\nname=packages-microsoft-com-prod\nbaseurl=https://packages.microsoft.com/rhel/9/prod\nenabled=1\ngpgcheck=1\ngpgkey=file:///etc/pki/rpm-gpg/microsoft.asc.gpg" > /etc/yum.repos.d/microsoft-prod.repo \
    && dnf install -y powershell \
    && dnf clean all

# Install Azure CLI
RUN rpm --import https://packages.microsoft.com/keys/microsoft.asc \
    && dnf install -y azure-cli \
    && dnf clean all

# Install Chrome for testing
RUN curl -sSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor > /etc/pki/rpm-gpg/google-chrome.asc.gpg \
    && echo -e "[google-chrome]\nname=google-chrome\nbaseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64\nenabled=1\ngpgcheck=1\ngpgkey=file:///etc/pki/rpm-gpg/google-chrome.asc.gpg" > /etc/yum.repos.d/google-chrome.repo \
    && dnf install -y google-chrome-stable \
    && dnf clean all

# Configure systemd for containers
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
    vim \
    libgirepository1.0-dev \
    ca-certificates \
    gnupg \
    && wget -q "https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb" \
    && dpkg -i packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y powershell \
    && mkdir -p /etc/apt/keyrings \
    && curl -sLS https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg \
    && chmod go+r /etc/apt/keyrings/microsoft.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" > /etc/apt/sources.list.d/azure-cli.list \
    && apt-get update \
    && apt-get install -y azure-cli=2.77.0-1~$(lsb_release -cs) \
    && apt-mark hold azure-cli \
    && wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt install -y ./google-chrome-stable_current_amd64.deb \
    && rm -rf google-chrome-stable_current_amd64.deb \
    && apt-get install -f \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
    #ansible \

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
    ca-certificates \
    lsb-release \
    gnupg \
    && mkdir -p /etc/apt/keyrings \
    && curl -sLS https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg \
    && chmod go+r /etc/apt/keyrings/microsoft.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" > /etc/apt/sources.list.d/azure-cli.list \
    && apt-get update \
    && apt-get install -y azure-cli=2.77.0-1~$(lsb_release -cs) \
    && apt-mark hold azure-cli \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

USER lme-user
CMD ["sleep", "infinity"]

# Pipeline-RHEL stage with minimal dependencies for Red Hat
FROM rhel-base AS pipeline-rhel

RUN dnf install -y \
    python3 \
    python3-pip \
    openssh-clients \
    curl \
    && rpm --import https://packages.microsoft.com/keys/microsoft.asc \
    && dnf install -y azure-cli \
    && dnf clean all

USER lme-user
CMD ["sleep", "infinity"]
