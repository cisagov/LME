#!/bin/bash

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Check if NON_ROOT_USER is set
if [ -z ${NON_ROOT_USER+x} ]; then 
    echo "var NON_ROOT_USER is unset"
    exit 1
else 
    echo "NON_ROOT_USER='$NON_ROOT_USER'"
fi

# Function to update or add a sysctl setting
update_sysctl() {
    local key=$1
    local value=$2
    local file="/etc/sysctl.conf"
    
    if grep -qE "^$key\s*=" "$file"; then
        sed -i "s/^$key\s*=.*/$key = $value/" "$file"
        echo "Updated $key in $file"
    elif grep -qE "^#\s*$key\s*=" "$file"; then
        sed -i "s/^#\s*$key\s*=.*/$key = $value/" "$file"
        echo "Uncommented and updated $key in $file"
    else
        echo "$key = $value" >> "$file"
        echo "Added $key to $file"
    fi
}

# Update sysctl settings
update_sysctl "net.ipv4.ip_unprivileged_port_start" "80"
update_sysctl "vm.max_map_count" "262144"
update_sysctl "net.core.rmem_max" "7500000"
update_sysctl "net.core.wmem_max" "7500000"

# Apply sysctl changes
sysctl -p

# Update limits.conf
limits_file="/etc/security/limits.conf"
limits_entry="$NON_ROOT_USER soft nofile 655360
$NON_ROOT_USER hard nofile 655360"

if grep -qE "^$NON_ROOT_USER\s+soft\s+nofile" "$limits_file"; then
    echo "$limits_file already configured for $NON_ROOT_USER. No changes needed."
else
    echo "$limits_entry" >> "$limits_file"
    echo "Updated $limits_file for $NON_ROOT_USER"
fi

# Display current values
echo "Current sysctl values:"
sysctl net.ipv4.ip_unprivileged_port_start
sysctl vm.max_map_count
sysctl net.core.rmem_max
sysctl net.core.wmem_max

echo "Script execution completed."