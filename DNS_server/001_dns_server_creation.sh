#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Check if the required arguments are provided
if [ "$#" -ne 2 ]; then
    echo -e "${RED}Usage: $0 <domain_name> <public_ip>${NC}"
    exit 1
fi

DOMAIN_NAME=$1
PUBLIC_IP=$2

# Function to check the success of the last command and print a message
check_success() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}$1 completed successfully.${NC}"
    else
        echo -e "${RED}$1 failed. Exiting.${NC}"
        exit 1
    fi
}

# Update and install necessary packages
echo -e "${YELLOW}Updating package list and installing BIND9...${NC}"
sudo apt update && sudo apt install bind9 bind9utils bind9-doc -y
check_success "Package installation"

# Define the DNS zone
echo -e "${YELLOW}Configuring named.conf.local...${NC}"
sudo bash -c "cat > /etc/bind/named.conf.local <<EOF
zone \"$DOMAIN_NAME\" {
    type master;
    file \"/etc/bind/zones/db.$DOMAIN_NAME\";
};
EOF"
check_success "DNS zone definition"

# Create the directory for zone files
echo -e "${YELLOW}Creating directory for zone files...${NC}"
sudo mkdir -p /etc/bind/zones
check_success "Zone directory creation"

# Define the DNS zone file
echo -e "${YELLOW}Creating DNS zone file...${NC}"
sudo bash -c 'cat > /etc/bind/zones/db.'"$DOMAIN_NAME"' <<EOF
\$TTL 604800
@   IN  SOA ns1.'"$DOMAIN_NAME"'. admin.'"$DOMAIN_NAME"'. (
              1     ; Serial
         604800     ; Refresh
          86400     ; Retry
        2419200     ; Expire
         604800 )   ; Negative Cache TTL

; Name servers
@       IN  NS      ns1.'"$DOMAIN_NAME"'.
@       IN  NS      ns2.'"$DOMAIN_NAME"'.

; A records for name servers
ns1     IN  A       '"$PUBLIC_IP"'
ns2     IN  A       '"$PUBLIC_IP"'

; A record for the domain
@       IN  A       '"$PUBLIC_IP"'

; Other records
www     IN  A       '"$PUBLIC_IP"'
EOF'
check_success "DNS zone file creation"

# Restart Bind9
echo -e "${YELLOW}Restarting Bind9...${NC}"
sudo systemctl restart bind9
check_success "Bind9 restart"

# Allow Bind9 through the firewall
echo -e "${YELLOW}Allowing Bind9 through the firewall...${NC}"
sudo ufw allow Bind9
check_success "Firewall configuration"

# Check the zone file and named configuration
echo -e "${YELLOW}Checking zone file and named configuration...${NC}"
sudo named-checkzone $DOMAIN_NAME /etc/bind/zones/db.$DOMAIN_NAME
check_success "Zone file check"
sudo named-checkconf
check_success "Named configuration check"

# Test the DNS server
echo -e "${YELLOW}Testing DNS server...${NC}"
dig @localhost $DOMAIN_NAME
check_success "DNS server test"

# Print a message if systemd-resolved restart throws an error
echo -e "${YELLOW}Restarting systemd-resolved...${NC}"
if ! sudo systemctl restart systemd-resolved; then
    echo -e "${RED}Failed to restart systemd-resolved. Please check the service status.${NC}"
else
    echo -e "${GREEN}systemd-resolved restarted successfully.${NC}"
fi

# Add an entry to the /etc/hosts file with the public IP
echo -e "${YELLOW}Adding entry to /etc/hosts...${NC}"
sudo bash -c "echo '$PUBLIC_IP dnsserver.$DOMAIN_NAME' >> /etc/hosts"
check_success "/etc/hosts entry"

# Restart systemd-resolved again
echo -e "${YELLOW}Restarting systemd-resolved again...${NC}"
sudo systemctl restart systemd-resolved
check_success "systemd-resolved restart"

# Configure netplan
echo -e "${YELLOW}Configuring netplan...${NC}"
sudo bash -c "cat > /etc/netplan/01-netcfg.yaml <<EOF
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: yes
      dhcp4-overrides:
        use-dns: false
      nameservers:
        addresses:
          - 127.0.0.1
EOF"
check_success "Netplan configuration"

# Apply the netplan configuration
echo -e "${YELLOW}Applying netplan configuration...${NC}"
sudo netplan apply
check_success "Netplan apply"

# Restart services
echo -e "${YELLOW}Restarting services...${NC}"
sudo systemctl restart systemd-resolved
check_success "systemd-resolved restart"
sudo systemctl reload bind9
check_success "Bind9 reload"

echo -e "${GREEN}DNS server setup for $DOMAIN_NAME completed. Ensure all configurations are correct and working.${NC}"
