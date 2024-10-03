#!/usr/bin/env bash
set -e

user=$(whoami)
sudo ./update_packages.sh

# Fix the DNS settings
sudo ./fix_dnsmasq.sh

# Set the GOPATH
sudo ./set_gopath.sh $user

# Install minimega
wget -O /tmp/minimega-2.9.deb https://github.com/sandia-minimega/minimega/releases/download/2.9/minimega-2.9.deb 

sudo apt install /tmp/minimega-2.9.deb

echo 'export PATH=$PATH:/opt/minimega/bin/' >> /etc/environment

# Set up the service and start minimega and miniweb services
sudo cp minimega.service miniweb.service /etc/systemd/system/  && sudo systemctl daemon-reload 

sudo systemctl enable minimega && sudo systemctl start minimega

sudo systemctl enable miniweb && sudo systemctl start miniweb

sudo ./create_bridge.sh 

sudo ./fix_dnsmasq.sh
