#!/bin/bash

DNS_FORWARD_ZONE="/etc/bind/db.bknj.lan"
DNS_REVERSE_ZONE="/etc/bind/db.10.172.16"
DOMAIN="bknj.lan"
REVERSE_DOMAIN="16.172.10.in-addr.arpa"

# Function to increment the serial number
increment_serial() {
    local zone_file="$1"
    local current_serial=$(grep -E "^[[:space:]]*[0-9]+" "$zone_file" | head -1 | awk '{print $1}')
    local new_serial=$((current_serial + 1))
    sudo sed -i "s/$current_serial/$new_serial/" "$zone_file"
    echo "Serial number incremented in $zone_file."
}

# Function to add a DNS record
add_dns_record() {
    read -p "Enter the hostname (e.g., web01): " hostname
    read -p "Enter the IP address (e.g., 192.168.1.100): " ip_address
    read -p "Enter the domain (e.g., bknj.lan): " domain

    echo "Adding A record to forward zone..."
    echo "${hostname}     IN      A       ${ip_address}" | sudo tee -a "$DNS_FORWARD_ZONE" > /dev/null

    local last_octet=$(echo "$ip_address" | awk -F '.' '{print $4}')
    echo "Adding PTR record to reverse zone..."
    echo "${last_octet}     IN      PTR      ${hostname}.${domain}." | sudo tee -a "$DNS_REVERSE_ZONE" > /dev/null

    echo "Incrementing serial numbers..."
    increment_serial "$DNS_FORWARD_ZONE"
    increment_serial "$DNS_REVERSE_ZONE"

    echo "Checking forward zone..."
    sudo named-checkzone "$domain" "$DNS_FORWARD_ZONE"
    if [ $? -ne 0 ]; then
        echo "Forward zone check failed. Exiting."
        exit 1
    fi

    echo "Checking reverse zone..."
    sudo named-checkzone "$REVERSE_DOMAIN" "$DNS_REVERSE_ZONE"
    if [ $? -ne 0 ]; then
        echo "Reverse zone check failed. Exiting."
        exit 1
    fi

    echo "DNS records added successfully."
}

# Function to delete a DNS record
delete_dns_record() {
    read -p "Enter the hostname to delete (e.g., web01): " hostname
    read -p "Enter the IP address to delete (e.g., 192.168.1.100): " ip_address

    # Delete the A record from the forward zone file
    echo "Deleting A record for ${hostname}.${DOMAIN}..."
    sudo sed -i "/^${hostname}\s\+IN\s\+A\s\+${ip_address}/d" "$FORWARD_ZONE_FILE"

    # Extract the last octet from the IP address for the PTR record
    local last_octet=$(echo "$ip_address" | awk -F '.' '{print $4}')

    # Delete the PTR record from the reverse zone file
    echo "Deleting PTR record for ${last_octet}.${REVERSE_DOMAIN}..."
    sudo sed -i "/^${last_octet}\s\+IN\s\+PTR\s\+${hostname}.${DOMAIN}\./d" "$REVERSE_ZONE_FILE"

    # Check if deletion was successful
    if ! grep -q "^${hostname}\s\+IN\s\+A\s\+${ip_address}" "$FORWARD_ZONE_FILE" && \
       ! grep -q "^${last_octet}\s\+IN\s\+PTR\s\+${hostname}.${DOMAIN}\." "$REVERSE_ZONE_FILE"; then
        echo "Records successfully deleted."
    else
        echo "Failed to delete records. Please verify the zone files."
    fi

    # Increment serial numbers
    increment_serial_number "$FORWARD_ZONE_FILE"
    increment_serial_number "$REVERSE_ZONE_FILE"

    # Reload the DNS service to apply changes
    reload_dns
}

# Function to modify a DNS record
modify_dns_record() {
    read -p "Enter the current hostname to modify (e.g., web01): " current_hostname
    read -p "Enter the new hostname (e.g., web02): " new_hostname
    read -p "Enter the current IP address (e.g., 192.168.1.100): " current_ip_address
    read -p "Enter the new IP address (e.g., 192.168.1.101): " new_ip_address

    echo "Modifying A record in forward zone..."
    sudo sed -i "s/${current_hostname}.*IN.*A.*${current_ip_address}/${new_hostname}     IN      A       ${new_ip_address}/" "$DNS_FORWARD_ZONE"

    local current_last_octet=$(echo "$current_ip_address" | awk -F '.' '{print $4}')
    local new_last_octet=$(echo "$new_ip_address" | awk -F '.' '{print $4}')
    echo "Modifying PTR record in reverse zone..."
    sudo sed -i "s/${current_last_octet}.*IN.*PTR.*${current_hostname}.${DOMAIN}/${new_last_octet}     IN      PTR      ${new_hostname}.${DOMAIN}/" "$DNS_REVERSE_ZONE"

    echo "Incrementing serial numbers..."
    increment_serial "$DNS_FORWARD_ZONE"
    increment_serial "$DNS_REVERSE_ZONE"

    echo "DNS records modified successfully."
}

# Function to test a DNS record
test_dns_record() {
    read -p "Enter the hostname to test (e.g., web01): " hostname
    echo "Testing A record for ${hostname}.${DOMAIN}..."
    dig +short "${hostname}.${DOMAIN}"

    read -p "Enter the IP address to test (e.g., 192.168.1.100): " ip_address
    local last_octet=$(echo "$ip_address" | awk -F '.' '{print $4}')
    echo "Testing PTR record for ${last_octet}.${REVERSE_DOMAIN}..."
    dig +short -x "$ip_address"
}

# Main menu
while true; do
    echo "DNS Management Script"
    echo "1. Add DNS record"
    echo "2. Delete DNS record"
    echo "3. Modify DNS record"
    echo "4. Test DNS record"
    echo "5. Exit"
    read -p "Choose an option [1-5]: " option

    case $option in
        1) add_dns_record ;;
        2) delete_dns_record ;;
        3) modify_dns_record ;;
        4) test_dns_record ;;
        5) exit 0 ;;
        *) echo "Invalid option. Please choose again." ;;
    esac
done