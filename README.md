# Juniper_Cert for doing Juniper certifications

has only 2 branches main and staging

testing on staging is ongoing

#Debian preconfig

useradd NetAdmin -s /bin/bash
usermod -aG sudo NetAdmin
mkdir /home/NetAdmin
chown NetAdmin:NetAdmin /home/NetAdmin
chmod 755 /home/NetAdmin


gns3 server install

cd /tmp
curl https://raw.githubusercontent.com/GNS3/gns3-server/master/scripts/remote-install.sh > gns3-remote-install.sh
sudo bash gns3-remote-install.sh --with-iou --with-i386-repository
