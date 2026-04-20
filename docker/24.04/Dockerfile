# Base stage with common dependencies
FROM ubuntu:24.04 AS base

ARG USER_ID=1000
ARG GROUP_ID=1000

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
    locales ca-certificates sudo openssh-client iptables vim \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    && existing_user=$(getent passwd $USER_ID | cut -d: -f1 || true) \
    && if [ -n "$existing_user" ] && [ "$existing_user" != "lme-user" ]; then userdel -r "$existing_user" 2>/dev/null || true; fi \
    && existing_group=$(getent group $GROUP_ID | cut -d: -f1 || true) \
    && if [ -n "$existing_group" ] && [ "$existing_group" != "lme-user" ]; then groupdel "$existing_group" 2>/dev/null || true; fi \
    && groupadd -g $GROUP_ID lme-user \
    && useradd -m -u $USER_ID -g lme-user lme-user \
    && usermod -aG sudo lme-user \
    && echo "lme-user ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

ENV BASE_DIR=/home/lme-user
WORKDIR $BASE_DIR

# Lme stage with full dependencies
FROM base AS lme

RUN apt-get update && apt-get install -y --no-install-recommends \
    systemd systemd-sysv \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

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

#COPY docker/24.04/lme-setup.service /etc/systemd/system/
#
#RUN chmod 644 /etc/systemd/system/lme-setup.service
#
## Enable the service
#RUN systemctl enable lme-setup.service

CMD ["/lib/systemd/systemd"]
