# Base stage with common dependencies
FROM ubuntu:22.04 AS base

ARG USER_ID=1001
ARG GROUP_ID=1001

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
    locales ca-certificates sudo sshpass openssh-client \
    python3 python3-venv python3-pip \
    python3-apt python3-dbus python3-gi \
    git curl wget ansible \
    lsb-release zip pkg-config \
    perl lintian \
    libcairo2-dev libdbus-1-dev distro-info libgirepository1.0-dev \
    libarchive13 \
    libgc1 \
    libsodium23 \
    libboost-context1.74.0 \
    libonig5 \
    libjq1 \
    jq \
    python3-pexpect \
    python3-ptyprocess \
    libdbi-perl \
    libdbd-sqlite3-perl \
    libwww-curl-perl \
    uidmap \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    && groupadd -g $GROUP_ID lme-user \
    && useradd -m -u $USER_ID -g lme-user --badnames lme-user \
    && usermod -aG sudo lme-user \
    && echo "lme-user ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

ENV BASE_DIR=/home/lme-user
WORKDIR $BASE_DIR

# Install Nix
RUN apt-get update && apt-get install -y \
    nix-bin \
    nix-setup-systemd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && usermod -aG nix-users root \
    && usermod -aG nix-users lme-user

# setup nix channels and install podman
RUN nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs && \
    nix-channel --update 

# Add Nix-specific PATH updates to shell profiles
RUN echo 'export PATH=$PATH:/nix/var/nix/profiles/default/bin' >> /root/.profile && \
    echo 'export PATH=$PATH:/nix/var/nix/profiles/default/bin' >> /root/.bashrc && \
    echo 'export PATH=$PATH:/nix/var/nix/profiles/default/bin' >> /home/lme-user/.profile && \
    echo 'export PATH=$PATH:/nix/var/nix/profiles/default/bin' >> /home/lme-user/.bashrc

# Set the PATH for the container itself
ENV PATH="${PATH}:/nix/var/nix/profiles/default/bin"

# Lme stage with systemd dependencies
FROM base AS lme

# Install only systemd-specific packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    kmod \
    dbus \
    udev \
    iptables \
    libdevmapper1.02.1 \
    libcryptsetup12 \
    systemd \
    systemd-sysv \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Pre-configure systemd
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

COPY docker/setup-systemd.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/setup-systemd.sh

CMD ["/usr/local/bin/container-init.sh"]
