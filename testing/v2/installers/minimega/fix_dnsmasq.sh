#!/usr/bin/env bash
# systemctl stop systemd-resolved

sed -i 's/nameserver 127.0.0.53/nameserver 127.0.0.1' /etc/resolv.conf
sed -i '/^127.0.0.1 localhost$/s/$/ ubuntu/' /etc/hosts

# systemctl disable systemd-resolved

if ! grep -q "server=8.8.4.4" /etc/dnsmasq.conf; then
    echo -e "strict-order\nlisten-address=127.0.0.1\nbind-interfaces\nserver=8.8.8.8\nserver=8.8.4.4" >> /etc/dnsmasq.conf
    
fi

systemctl restart dnsmasq