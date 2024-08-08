#!/usr/bin/env bash

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run with sudo or as root."
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update

# Get Ubuntu version
ubuntu_version=$(lsb_release -rs)
major_version=$(echo $ubuntu_version | cut -d. -f1)

# Common packages for both versions
common_packages=(
    libpcap-dev
    libreadline-dev
    qemu-kvm
    openvswitch-switch
    dnsmasq
    bird
    build-essential
    tmux
    curl
    wget
    nano
    git
    unzip
    golang
    jq
    qemu-utils
    libguestfs-tools
)

# Check Ubuntu version and install appropriate packages
if [ "$major_version" -lt 24 ]; then
    echo "Ubuntu version is below 24. Installing packages for Ubuntu $ubuntu_version"
    ./check_dpkg_lock.sh apt-get install -y "${common_packages[@]}" qemu
else
    echo "Ubuntu version is 24 or above. Installing packages for Ubuntu $ubuntu_version"
    ./check_dpkg_lock.sh apt-get install -y "${common_packages[@]}" \
        qemu-system \
        qemu-user \
        qemu-user-static \
        qemu-utils \
        qemu-block-extra
fi