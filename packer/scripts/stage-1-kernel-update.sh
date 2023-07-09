#!/bin/bash

# Install elrepo repo
yum install -y https://www.elrepo.org/elrepo-release-9.el9.elrepo.noarch.rpm 

# Install new kernel
yum --enablerepo elrepo-kernel install kernel-ml -y

# Update GRUB
grub2-mkconfig -o /boot/grub2/grub.cfg
grub2-set-default 0
echo "Grub update done."

# Reboot VM
shutdown -r now
