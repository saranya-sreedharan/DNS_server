#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Check if the required arguments are provided
if [ "$#" -ne 2 ]; then
    echo -e "${RED}Usage: $0 <primary_dns_ip> <domain_name>${NC}"
    exit 1
fi

PRIMARY_DNS_IP=$1
DOMAIN_NAME=$2

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

# Configure named.conf.local for the secondary DNS server
echo -e "${YELLOW}Configuring named.conf.local...${NC}"
sudo bash -c "cat > /etc/bind/named.conf.local <<EOF
zone \"$DOMAIN_NAME\" {
    type slave;
    file \"/etc/bind/zones/slave.db.$DOMAIN_NAME\";
    masters { $PRIMARY_DNS_IP; };
};
EOF"
check_success "Secondary DNS zone definition"

# Create the directory for zone files
echo -e "${YELLOW}Creating directory for zone files...${NC}"
sudo mkdir -p /etc/bind/zones
check_success "Zone directory creation"

# Restart Bind9
echo -e "${YELLOW}Restarting Bind9...${NC}"
sudo systemctl restart bind9
check_success "Bind9 restart"

# Allow Bind9 through the firewall
echo -e "${YELLOW}Allowing Bind9 through the firewall...${NC}"
sudo ufw allow Bind9
check_success "Firewall configuration"

# Check the named configuration
echo -e "${YELLOW}Checking named configuration...${NC}"
sudo named-checkconf
check_success "Named configuration check"

# Print a success message
echo -e "${GREEN}Secondary DNS server setup for $DOMAIN_NAME completed. Ensure all configurations are correct and working.${NC}"
