# Juniper_Cert for doing Juniper certifications


#Debian preconfig

useradd NetAdmin -s /bin/bash
usermod -aG sudo NetAdmin
mkdir /home/NetAdmin
chown NetAdmin:NetAdmin /home/NetAdmin
chmod 755 /home/NetAdmin
