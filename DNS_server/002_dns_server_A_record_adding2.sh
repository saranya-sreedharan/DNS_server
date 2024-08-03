#!/bin/bash

# Color definitions
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print success message
print_success() {
    echo -e "${GREEN}$1${NC}"
}

# Function to print error message
print_error() {
    echo -e "${RED}$1${NC}"
}

# Check if the user is root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root"
   exit 1
fi

ZONE_FILE="/etc/bind/zones/db.mnsp.co.in"

# Check if both arguments are provided
if [ "$#" -ne 2 ]; then
    print_error "Usage: $0 <A record name> <IP address>"
    exit 1
fi

# Get A record name and IP address from arguments
RECORD_NAME=$1
IP_ADDRESS=$2

# Validate IP address format
if [[ ! $IP_ADDRESS =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    print_error "Invalid IP address format"
    exit 1
fi

# Add A record under the "Other records" section
if sudo sed -i "/; Other records/a\\${RECORD_NAME}     IN  A       ${IP_ADDRESS}" ${ZONE_FILE}; then
    print_success "A record added successfully under 'Other records' section."
else
    print_error "Failed to add A record."
    exit 1
fi

# Check the zone file
if sudo named-checkzone mnsp.co.in ${ZONE_FILE}; then
    print_success "Zone file check passed."
else
    print_error "Zone file check failed. Exiting."
    exit 1
fi

# Reload Bind9
if sudo systemctl reload bind9; then
    print_success "Bind9 reloaded successfully."
else
    print_error "Failed to reload Bind9."
    exit 1
fi

sleep 10 

# Test the new A record
if ping -c 4 ${RECORD_NAME}.mnsp.co.in; then
    print_success "Successfully pinged ${RECORD_NAME}.mnsp.co.in."
else
    print_error "Failed to ping ${RECORD_NAME}.mnsp.co.in. Please check your configuration."
fi
