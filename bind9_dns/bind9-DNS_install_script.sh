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
sudo apt-get update && sudo apt-get upgrade -y

# Install bind9 and other packages
sudo apt install -y bind9 bind9utils bind9-doc dnsutils

#Configuring Forwarder of bind9 Service
backup_file /etc/bind/named.conf.options
cat <<EOL | sudo tee /etc/bind/named.conf.options
acl trustedclients {
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

#Configuring Zones of bind9 Service
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

# Configuring Forward lookup zone of bind9 service
sudo cp /etc/bind/db.local /etc/bind/db.bknj.lan
cat <<EOL | sudo tee /etc/bind/db.bknj.lan
;
; BIND data file for bknj.lan zone
;
\$TTL    604800
@       IN      SOA     ns-srv01.bknj.lan. NetAdmin.bknj.lan. (
                              3         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      ns-srv01.bknj.lan.

ns-srv01     IN      A       10.172.16.101
dhcp-srv01   IN      A       10.172.16.100
gw           IN      A       10.172.16.1
EOL

# Configuring Reverse lookup zone of bind9 service
sudo cp /etc/bind/db.127 /etc/bind/db.10.172.16
cat <<EOL | sudo tee /etc/bind/db.10.172.16
;
; BIND reverse data file for bknj.lan zone
;
\$TTL    604800
@       IN      SOA     ns-srv01.bknj.lan. NetAdmin.bknj.lan. (
                              3         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      ns-srv01.bknj.lan.

100     IN     PTR      dhcp-srv01.bknj.lan.
100     IN     PTR      ns-srv01.bknj.lan.
EOL

# Run the named-checkconf command and check for errors in bind9 zone sysntax
check_named_conf() {
  if ! sudo named-checkconf; then
    echo "named-checkconf failed."
    return 1
  fi
}

check_named_checkzone_forward() {
  if ! sudo named-checkzone bknj.lan /etc/bind/db.bknj.lan; then
    echo "Forward named-checkzone failed. Exiting script."
    return 1
  fi
}

check_named_checkzone_reverse() {
  if ! sudo named-checkzone 16.172.10.in-addr.arpa /etc/bind/db.10.172.16; then
    echo "Reverse named-checkzone failed. Exiting script."
    return 1
  fi
}


# Call the functions and check their results
check_named_conf
if [ $? -ne 0 ]; then
  echo "Exiting due to error(s) in named.conf.options file [DNS Forwarder] or named.conf.local file [DNS Zone Defenition]. "
  return 1
fi

check_named_checkzone_forward
if [ $? -ne 0 ]; then
  echo "Exiting due to error(s) in db.bknj.lan file [Forward zone]. "
  return 1
fi

check_named_checkzone_reverse
if [ $? -ne 0 ]; then
  echo "Exiting due to error(s) in db.10.172.16 [Reverse zone]."
  return 1
fi

# Continuing the script, if tests passed
echo "Syntax checks passed, Continuing setup..."

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
      addresses: [10.172.16.101/24]
      gateway4: 10.172.16.1
      nameservers:
        addresses: 127.0.0.1 
EOL

# Apply the netplan configuration
sudo netplan apply

# Remove Interface config from /etc/network/interfaces
sudo sed -i '/^auto ens3/,/^iface ens3 inet dhcp/d' /etc/network/interfaces
sudo sed -i '/^auto ens4/,/^iface ens4 inet static/d' /etc/network/interfaces

sudo hostnamectl set-hostname dns-srv01
