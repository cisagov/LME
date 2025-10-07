# Base stage with common dependencies
FROM registry.access.redhat.com/ubi9/ubi:9.6 AS base

ARG USER_ID=1002
ARG GROUP_ID=1002

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# Skip systemd updates to avoid conflicts, install base packages
RUN dnf install -y \
    glibc-langpack-en sudo openssh-clients git vim iptables-nft \
    && dnf clean all \
    && GROUP_ID_VAR=$GROUP_ID \
    && USER_ID_VAR=$USER_ID \
    && while getent group $GROUP_ID_VAR > /dev/null 2>&1; do GROUP_ID_VAR=$((GROUP_ID_VAR + 1)); done \
    && while getent passwd $USER_ID_VAR > /dev/null 2>&1; do USER_ID_VAR=$((USER_ID_VAR + 1)); done \
    && groupadd -g $GROUP_ID_VAR lme-user \
    && useradd -m -u $USER_ID_VAR -g lme-user lme-user \
    && usermod -aG wheel lme-user \
    && echo "lme-user ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers \
    && echo "Defaults:lme-user !requiretty" >> /etc/sudoers \
    && echo "#%PAM-1.0" > /etc/pam.d/sudo \
    && echo "auth       include      system-auth" >> /etc/pam.d/sudo \
    && echo "account    sufficient   pam_permit.so" >> /etc/pam.d/sudo \
    && echo "password   include      system-auth" >> /etc/pam.d/sudo \
    && echo "session    include      system-auth" >> /etc/pam.d/sudo

ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

ENV BASE_DIR=/home/lme-user
WORKDIR $BASE_DIR

# Lme stage with full dependencies
FROM base AS lme


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

#COPY docker/rhel9/lme-setup.service /etc/systemd/system/
#
#RUN chmod 644 /etc/systemd/system/lme-setup.service
#
## Enable the service
#RUN systemctl enable lme-setup.service

CMD ["/lib/systemd/systemd"] 
