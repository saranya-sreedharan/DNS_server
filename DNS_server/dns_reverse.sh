#!/bin/bash

# Stop BIND9 service
sudo systemctl stop bind9

# Remove BIND9 and configuration files
sudo apt purge -y bind9 bind9-utils net-tools
sudo rm -rf /etc/bind

# Restore original named.conf if backup exists
if [ -f /etc/bind/named.conf.backup ]; then
    sudo mv /etc/bind/named.conf.backup /etc/bind/named.conf
fi

sudo rm -rf /var/cache/bind
sudo rm -rf /etc/bind
echo "Reverted DNS server setup."
