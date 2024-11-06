#!/bin/bash
sudo parted /dev/sda ---pretend-input-tty <<EOF
resizepart
1
Yes
100%
EOF
