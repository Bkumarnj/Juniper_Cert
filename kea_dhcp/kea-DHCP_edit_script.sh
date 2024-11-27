#!/bin/bash

CONFIG_FILE="/etc/kea/kea-dhcp4.conf"
BACKUP_FILE="${CONFIG_FILE}.$(date +%F_%T).bak"

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
done
