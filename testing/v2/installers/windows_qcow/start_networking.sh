#!/usr/bin/env bash


# Run from anywhere
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"



"${SCRIPT_DIR}/../ubuntu_qcow_maker/create_tap.sh" && "${SCRIPT_DIR}/../ubuntu_qcow_maker/setup_dnsmasq.sh" && "${SCRIPT_DIR}/../ubuntu_qcow_maker/iptables.sh"

