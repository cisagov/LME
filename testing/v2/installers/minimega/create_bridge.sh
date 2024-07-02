#!/bin/sh
set -e 
sudo ovs-vsctl add-br mega_bridge 
sudo ovs-vsctl set bridge mega_bridge stp_enable=false