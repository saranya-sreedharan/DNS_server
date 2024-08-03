#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Check if the required arguments are provided
if [ "$#" -ne 2 ]; then
    echo -e "${RED}Usage: $0 <secondary_dns_ip> <domain_name>${NC}"
    exit 1
fi

SECONDARY_DNS_IP=$1
DOMAIN_NAME=$2
ZONE_FILE="/etc/bind/zones/db.$DOMAIN_NAME"

# Function to check the success of the last command and print a message
check_success() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}$1 completed successfully.${NC}"
    else
        echo -e "${RED}$1 failed. Exiting.${NC}"
        exit 1
    fi
}

# Update the zone file on the primary DNS server
echo -e "${YELLOW}Updating zone file on primary DNS server...${NC}"
sudo sed -i 's/^@       IN  NS      ns1.'"$DOMAIN_NAME"'\./@       IN  NS      ns1.'"$DOMAIN_NAME"'\.\n@       IN  NS      ns2.'"$DOMAIN_NAME"'\./' $ZONE_FILE
sudo sed -i 's/^ns1     IN  A       .*$/ns1     IN  A       54.227.115.29\nns2     IN  A       '"$SECONDARY_DNS_IP"'/g' $ZONE_FILE
check_success "Zone file update"

# Allow zone transfers to the secondary DNS server
echo -e "${YELLOW}Configuring zone transfer permissions...${NC}"
sudo sed -i '/zone "'"$DOMAIN_NAME"'"/!b;n;c\        allow-transfer { '"$SECONDARY_DNS_IP"'; };' /etc/bind/named.conf.local

# Manually ensure the named.conf.local has correct syntax
echo -e "${YELLOW}Ensuring correct named.conf.local configuration...${NC}"
sudo bash -c "cat > /etc/bind/named.conf.local <<EOF
zone \"$DOMAIN_NAME\" {
    type master;
    file \"/etc/bind/zones/db.$DOMAIN_NAME\";
    allow-transfer { $SECONDARY_DNS_IP; };
};
EOF"
check_success "Zone transfer configuration"

# Check the zone file and named configuration
echo -e "${YELLOW}Checking zone file and named configuration...${NC}"
sudo named-checkzone $DOMAIN_NAME $ZONE_FILE
check_success "Zone file check"
sudo named-checkconf
check_success "Named configuration check"

# Restart Bind9
echo -e "${YELLOW}Restarting Bind9...${NC}"
sudo systemctl restart named
if [ $? -ne 0 ]; then
    echo -e "${RED}Bind9 restart failed. Check the status and logs below for more details.${NC}"
    sudo systemctl status named.service
    sudo journalctl -xeu named.service
    exit 1
else
    echo -e "${GREEN}Bind9 restarted successfully.${NC}"
fi
