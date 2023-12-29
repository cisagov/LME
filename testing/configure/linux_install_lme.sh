#!/bin/bash

# Change to the directory where the script is located
cd "$(dirname "$0")" || exit 1

# Default username
username="admin.ackbar"

# Parse flag-based arguments
while getopts "u:" opt; do
  case $opt in
    u) username=$OPTARG ;;
    \?) echo "Invalid option -$OPTARG" >&2; exit 1 ;;
  esac
done

# Download a copy of the LME files
sudo git clone https://github.com/cisagov/lme.git /opt/lme/
# Execute script with root privileges
sudo ./linux_install_lme.exp

sudo cp /opt/lme/files_for_windows.zip /home/"$username"/
sudo chown "$username":"$username" /home/"$username"/files_for_windows.zip