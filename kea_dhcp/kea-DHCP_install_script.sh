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
apt install curl apt-transport-https -y

#Install the Repositories for Kea DHCP server
curl -1sLf 'https://dl.cloudsmith.io/public/isc/kea-2-6/setup.deb.sh' | sudo -E bash

# Install the Kea DHCP server
sudo apt-get install -y isc-kea-dhcp4-server

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
            "pools": [ { "pool": "10.16.22.10 - 10.16.21.250" } ],
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
reboot
