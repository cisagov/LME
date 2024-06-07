#!/usr/bin/env bash
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run with sudo or as root."
  exit 1
fi
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y libpcap-dev libreadline-dev qemu qemu-kvm openvswitch-switch dnsmasq bird build-essential tmux curl wget nano git unzip golang