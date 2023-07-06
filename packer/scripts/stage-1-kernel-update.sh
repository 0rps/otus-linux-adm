#!/bin/bash

# On January 31, 2022, CentOS team has finally removed all packages for CentOS 8 from the official mirrors, they moved to https://vault.centos.org 
sed -i -e "s|mirrorlist=|#mirrorlist=|g" /etc/yum.repos.d/CentOS-*
sed -i -e "s|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g" /etc/yum.repos.d/CentOS-*

# Install elrepo repo
yum install -y https://www.elrepo.org/elrepo-release-8.el8.elrepo.noarch.rpm 
# Install new kernel
yum --enablerepo elrepo-kernel install kernel-ml -y

# Update GRUB
grub2-mkconfig -o /boot/grub2/grub.cfg
grub2-set-default 0
echo "Grub update done."
# Reboot VM
shutdown -r now
