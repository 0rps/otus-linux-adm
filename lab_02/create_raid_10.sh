#!/bin/bash
mdadm --zero-superblock --force /dev/sd{c,d,e,f,g}

mdadm --create --verbose /dev/md0 -l 10 -n 4 /dev/sd{c,d,e,f}

# fail, remove and add devices
mdadm /dev/md0 --fail /dev/sdc 
mdadm /dev/md0 --remove /dev/sdc
mdadm /dev/md0 --add /dev/sdg

# configure mdadm.conf
echo "DEVICE partitions" >> /etc/mdadm/mdadm.conf
mdadm --detail --scan --verbose | awk '/ARRAY/ {print}' >> /etc/mdadm/mdadm.conf
update-initramfs -u 

# create partitions and mount them
parted -s /dev/md0 mklabel gpt
parted /dev/md0 mkpart primary ext4 0% 20%
parted /dev/md0 mkpart primary ext4 20% 40%
parted /dev/md0 mkpart primary ext4 40% 60%
parted /dev/md0 mkpart primary ext4 60% 80%
parted /dev/md0 mkpart primary ext4 80% 100%
for i in $(seq 1 5); do mkfs.ext4 /dev/md0p$i; done
mkdir -p /raid/part{1,2,3,4,5}
for i in $(seq 1 5); do mount /dev/md0p$i /raid/part$i; done

# add volumes to fstab
for i in $(seq 1 5); do echo "/dev/md0p$i /raid/part$i ext4 defaults,nofail,discard 0 0" | tee -a /etc/fstab; done
