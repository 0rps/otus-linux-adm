#!/bin/bash
sudo yum install -y nfs-utils 

# Enable firewall
sudo systemctl enable firewalld --now 

# Configure NFS directory mounting
sudo echo "192.168.56.10:/srv/share/ /mnt nfs vers=3,proto=udp,noauto,x-systemd.automount 0 0" >> /etc/fstab
sudo reboot