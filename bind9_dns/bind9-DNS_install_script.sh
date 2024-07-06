#!/bin/bash

# Function to create a backup
backup_file() {
  local file=$1
  if [ -f "$file" ]; then
    sudo cp "$file" "${file}.bak"
    echo "Backup of $file created at ${file}.bak"
  fi
}

# Update & Upgrade the package list
sudo apt-get update
sudo apt-get upgrade -y

# Install bind9 and other packages
sudo apt install -y bind9 bind9utils bind9-doc dnsutils

#Configuring Forwarder of bind9 Service
backup_file /etc/bind/named.conf.options
cat <<EOL | sudo tee /etc/bind/named.conf.options
acl trustedclinets {
      localhost;
      localnets;
      10.16.21.0/24;
      10.16.22.0/24;
};

options {
        directory "/var/cache/bind";

        recursion yes;
        allow-query { trustedclients; };
        allow-query-cache { trustedclients; };
        allow-recursion { trustedclients; };

        forwarders {
                1.1.1.2;
                1.0.0.2;
        };

        dnssec-validation no;

        listen-on-v6 port 53 { ::1; };
        listen-on port 53 { 127.0.0.1; 10.172.16.101; };
};
EOL

backup_file /etc/bind/named.conf.local
cat <<EOL | sudo tee /etc/bind/named.conf.local
zone "bknj.lan" {
        type master;
        file "/etc/bind/db.bknj.lan";
};

zone "16.172.10.in-addr.arpa" {
        type master;
        file "/etc/bind/db.10.172.16";
};
EOL

# Run the named-checkconf command and check for errors in any bind9 sysntax
check_named_conf() {
  if ! sudo named-checkconf; then
    echo "named-checkconf failed."
    return 1
  fi
}

check_named_conf

if [ $? -ne 0 ]; then
  echo "Exiting due to error."
  return 1
fi

# Continuing the script, if it passes
echo "named-checkconf succeeded. Continuing setup..."

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
      addresses: [10.172.16.101/24]
      gateway4: 10.172.16.1
      nameservers:
        addresses: [8.8.8.8, 8.8.9.9]
EOL

# Apply the netplan configuration
sudo netplan apply

# Remove specific lines from /etc/network/interfaces
sudo sed -i '/^auto ens3/,/^iface ens3 inet dhcp/d' /etc/network/interfaces
sudo sed -i '/^auto ens4/,/^iface ens4 inet static/d' /etc/network/interfaces