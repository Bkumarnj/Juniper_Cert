#!/bin/bash

# Function to create a backup
backup_file() {
  local file=$1
  if [ -f "$file" ]; then
    sudo cp "$file" "${file}.bak"
    echo "Backup of $file created at ${file}.bak"
  fi
}

# Update and Upgrade the package list
sudo apt-get update && sudo apt-get upgrade -y

#Install the Dependencies for Kea DHCP server
sudo apt install curl apt-transport-https -y

#Install the Repositories for Kea DHCP server
curl -1sLf 'https://dl.cloudsmith.io/public/isc/kea-2-6/setup.deb.sh' | sudo -E bash

# Install the Kea DHCP server
sudo apt-get install -y isc-kea-dhcp4-server

#Install jq dependency for Kea edit script
sudo apt install -y jq

# Backup and create the kea-dhcp4 configuration file
backup_file /etc/kea/kea-dhcp4.conf
cat <<EOL | sudo tee /etc/kea/kea-dhcp4.conf
{
"Dhcp4": {
    "interfaces-config": {
        "interfaces": ["ens4"]
    },

    "authoritative": true,
    
    "lease-database": {
        "type": "memfile",
        "persist": true,
        "name": "/var/lib/kea/kea-leases4.csv",
        "lfc-interval": 3600
    },

    "renew-timer": 15840,
    "rebind-timer": 27720,
    "valid-lifetime": 31680,

    "option-data": [
        {
            "name": "domain-name-servers",
            "data": "10.16.17.101, 10.16.17.102"
        },

        {
            "name": "domain-search",
            "data": "bknj.lan"
        }
    ],

    "subnet4": [
        {
            "id":1,
            "subnet": "10.16.21.0/24",
            "pools": [ { "pool": "10.16.21.10 - 10.16.21.250" } ],
            "option-data": [
                {
                    "name": "routers",
                    "data": "10.16.21.1"
                }
            ]
            
            // Add reservations here
        },
        {
            "id":2,
            "subnet": "10.16.22.0/24",
            "pools": [ { "pool": "10.16.22.10 - 10.16.22.250" } ],
            "option-data": [
                {
                    "name": "routers",
                    "data": "10.16.22.1"
                }
            ]
            
            // Add reservations here
        }
        // Add subnets here
    ]
}
}
EOL

# Backup and set the static IP configuration for ens4
backup_file /etc/netplan/90-default.yaml
sudo tee /etc/netplan/90-default.yaml <<EOL
network:
  version: 2
  renderer: networkd
  ethernets:
    ens3: 
      dhcp4: true
    ens4:
      dhcp4: no
      addresses: [10.172.16.100/24]
      gateway4: 10.172.16.1
      nameservers:
        addresses: [8.8.8.8, 8.8.9.9]
EOL

# Apply the netplan configuration
sudo netplan apply

# Remove Interface config from /etc/network/interfaces
sudo sed -i '/^auto ens3/,/^iface ens3 inet dhcp/d' /etc/network/interfaces
sudo sed -i '/^auto ens4/,/^iface ens4 inet static/d' /etc/network/interfaces

# Enable and start the Kea DHCP service
sudo systemctl enable isc-kea-dhcp4-server
sudo systemctl start isc-kea-dhcp4-server

# Check the status of the Kea DHCP service
sudo systemctl status isc-kea-dhcp4-server

# Changing hostname to DHCP-Server and a reboot o make it permanent
sudo hostnamectl set-hostname dhcp-srv01

# Save the configuration management script
cat << 'EOF' | sudo tee /usr/local/bin/kea_dhcp_config.sh > /dev/null
#!/bin/bash

CONFIG_FILE="/etc/kea/kea-dhcp4.conf"
BACKUP_FILE="${CONFIG_FILE}.$(date +%F_%T).bak"

# Capture the initial hash of the configuration file before any changes
ORIGINAL_HASH=$(sha256sum "$CONFIG_FILE" | awk '{ print $1 }')

# Creating Tmp config file
TEMP_CONFIG_FILE="/tmp/kea-dhcp4.conf.tmp"

# Back up the original configuration file
echo "Backing up $CONFIG_FILE to $BACKUP_FILE"
sudo cp "$CONFIG_FILE" "$BACKUP_FILE"

# Load the configuration as a JSON object
CONFIG_JSON=$(cat "$CONFIG_FILE")

# Function to add a subnet
add_subnet() {
    read -p "Enter subnet (e.g., 10.16.21.0/24): " subnet
    read -p "Enter pool range (e.g., 10.16.21.10-10.16.21.250): " pool
    read -p "Enter valid-lifetime in seconds (e.g., 31680): " valid_lifetime

    NEW_SUBNET=$(jq --arg subnet "$subnet" --arg pool "$pool" --argjson lifetime "$valid_lifetime" '.Dhcp4.subnet4 += [{"subnet": $subnet, "pools": [{"pool": $pool}], "valid-lifetime": $lifetime}]' <<< "$CONFIG_JSON")

    CONFIG_JSON="$NEW_SUBNET"
    echo "Added subnet $subnet."
}

# Function to edit a subnet
edit_subnet() {
    read -p "Enter subnet to edit (e.g., 10.16.21.0/24): " subnet
    read -p "Enter new pool range (e.g., 10.16.21.10-10.16.21.250): " pool
    read -p "Enter new valid-lifetime in seconds (e.g., 31680): " valid_lifetime

    EDITED_CONFIG=$(jq --arg subnet "$subnet" --arg pool "$pool" --argjson lifetime "$valid_lifetime" '
        .Dhcp4.subnet4 |= map(if .subnet == $subnet then .pools[0].pool = $pool | .["valid-lifetime"] = $lifetime else . end)
    ' <<< "$CONFIG_JSON")

    CONFIG_JSON="$EDITED_CONFIG"
    echo "Edited subnet $subnet."
}

# Function to delete a subnet
delete_subnet() {
    read -p "Enter subnet to delete (e.g., 10.16.21.0/24): " subnet

    DELETED_CONFIG=$(jq --arg subnet "$subnet" '.Dhcp4.subnet4 |= map(select(.subnet != $subnet))' <<< "$CONFIG_JSON")

    CONFIG_JSON="$DELETED_CONFIG"
    echo "Deleted subnet $subnet."
}

# Function to modify general settings
modify_settings() {
    read -p "Enter new default lease time in seconds (e.g., 3600): " default_lease_time
    read -p "Enter new max lease time in seconds (e.g., 86400): " max_lease_time

    MODIFIED_CONFIG=$(jq --argjson default_time "$default_lease_time" --argjson max_time "$max_lease_time" '
        .Dhcp4["valid-lifetime"] = $default_time |
        .Dhcp4["max-valid-lifetime"] = $max_time
    ' <<< "$CONFIG_JSON")

    CONFIG_JSON="$MODIFIED_CONFIG"
    echo "Updated lease times."
}

# Main Menu
while true; do
    echo -e "\n--- Kea DHCP Configuration Script ---"
    echo "1) Add Subnet"
    echo "2) Edit Subnet"
    echo "3) Delete Subnet"
    echo "4) Modify General Settings"
    echo "5) Save and Apply Changes"
    echo "6) Exit"
    read -p "Choose an option: " option

    case $option in
        1) add_subnet ;;
        2) edit_subnet ;;
        3) delete_subnet ;;
        4) modify_settings ;;
        5)
            echo "$CONFIG_JSON" | sudo tee "$CONFIG_FILE" > /dev/null
            echo "Changes saved to $CONFIG_FILE. Restarting Kea DHCP service..."
            sudo systemctl restart isc-kea-dhcp4-server
            echo "Service restarted."
            ;;
        6) break ;;
        *) echo "Invalid option. Please try again." ;;
    esac

    # After completing the chosen operation, calculate a new hash of the config file
    NEW_HASH=$(sha256sum "$CONFIG_FILE" | awk '{ print $1 }')

    # Compare the hashes to check if any changes were made
    if [[ "$ORIGINAL_HASH" != "$NEW_HASH" ]]; then
        echo "Configuration has changed. Restarting $SERVICE_NAME..."
        sudo systemctl restart "$SERVICE_NAME"
    else
        echo "No changes detected in configuration. Skipping service restart."
    fi
done

EOF

# Make the script executable
sudo chmod +x /usr/local/bin/kea_dhcp_config.sh

# Add custom command alias for initiating the script
echo "Adding custom command to initiate Kea DHCP configuration management..."
echo "alias config-kea='sudo /usr/local/bin/kea_dhcp_config.sh'" | sudo tee -a ~/.zshrc > /dev/null
source ~/.zshrc

# Final message
echo "Installation complete. Use 'config-kea' to manage Kea DHCP configuration."


reboot
