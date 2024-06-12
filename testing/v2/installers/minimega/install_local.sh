#!/usr/bin/env bash
$user=$(whoami)
set -e

# Run the update_packages.sh script on the remote machine this reboots the machine
sudo ./update_packages.sh

# Fix the DNS settings
sudo ./fix_dnsmasq.sh

# Set the GOPATH
sudo ./set_gopath.sh $user

# Install minimega
wget -O /tmp/minimega-2.9.deb https://github.com/sandia-minimega/minimega/releases/download/2.9/minimega-2.9.deb 
sudo apt install /tmp/minimega-2.9.deb

# Set up the service and start minimega and miniweb services
sudo cp minimega.service miniweb.service /etc/systemd/system/  && sudo systemctl daemon-reload 

sudo systemctl enable minimega && sudo systemctl start minimega

sudo systemctl enable miniweb && sudo systemctl start miniweb
