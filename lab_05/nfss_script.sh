#!/bin/bash
sudo yum install -y nfs-utils

# Enable firewall
sudo systemctl enable firewalld --now 
sudo firewall-cmd --add-service="nfs3" \
--add-service="rpc-bind" \
--add-service="mountd" \
--permanent 

# Enable NFS
sudo systemctl enable nfs --now 

# Сreate shared directory
sudo mkdir -p /srv/share/upload 
sudo chown -R nfsnobody:nfsnobody /srv/share 
sudo chmod 0777 /srv/share/upload 

# Create nfs config to allow the client to connect
sudo cat << EOF > /etc/exports 
/srv/share 192.168.56.11/32(rw,sync,root_squash) 
EOF

sudo reboot