# Base stage with common dependencies
FROM registry.access.redhat.com/ubi9/ubi:9.6 AS base

ARG USER_ID=1002
ARG GROUP_ID=1002

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# Skip systemd updates to avoid conflicts, install base packages
RUN dnf install -y \
    glibc-langpack-en sudo openssh-clients git vim iptables-nft dbus-daemon \
    && dnf clean all \
    && existing_user=$(getent passwd $USER_ID | cut -d: -f1 || true) \
    && if [ -n "$existing_user" ] && [ "$existing_user" != "lme-user" ]; then userdel -r "$existing_user" 2>/dev/null || true; fi \
    && existing_group=$(getent group $GROUP_ID | cut -d: -f1 || true) \
    && if [ -n "$existing_group" ] && [ "$existing_group" != "lme-user" ]; then groupdel "$existing_group" 2>/dev/null || true; fi \
    && groupadd -g $GROUP_ID lme-user \
    && useradd -m -u $USER_ID -g lme-user lme-user \
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

# Re-enable DBus (system bus) after the cleanup above wiped its wants symlinks.
# crun (used by nested podman) and loginctl both require /run/dbus/system_bus_socket,
# which only gets created if dbus.socket is pulled in by sockets.target at boot.
RUN systemctl unmask dbus.socket dbus-broker.service systemd-logind.service dbus-org.freedesktop.login1.service || true && \
    systemctl enable dbus.socket dbus-broker.service systemd-logind.service

#COPY docker/rhel9/lme-setup.service /etc/systemd/system/
#
#RUN chmod 644 /etc/systemd/system/lme-setup.service
#
## Enable the service
#RUN systemctl enable lme-setup.service

CMD ["/lib/systemd/systemd"] 
