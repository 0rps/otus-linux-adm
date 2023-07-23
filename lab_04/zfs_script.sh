#!/bin/bash

#install zfs repo
yum install -y http://download.zfsonlinux.org/epel/zfs-release.el7_8.noarch.rpm
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-zfsonlinux
yum install -y epel-release kernel-devel zfs

# install zfs and configure it
yum-config-manager --disable zfs
yum-config-manager --enable zfs-kmod
yum install -y zfs
modprobe zfs

# install wget
yum install -y wget

# PART 1
# initialize zfs pool 
zpool create otus1 mirror /dev/sdb /dev/sdc
zpool create otus2 mirror /dev/sdd /dev/sde
zpool create otus3 mirror /dev/sdf /dev/sdg
zpool create otus4 mirror /dev/sdh /dev/sdi


# set compression
zfs set compression=lz4 otus1
zfs set compression=lzjb otus1
zfs set compression=lz4 otus2
zfs set compression=gzip-9 otus3
zfs set compression=zle otus4


# download file
wget -P ./ https://gutenberg.org/cache/epub/2600/pg2600.converter.log
for i in {1..4}; do cp ./pg2600.converter.log /otus$i/; done
rm ./pg2600.converter.log

# here you can test compression results via the following commands:
# -> zfs get all | grep compression
# -> ls -l /otus*

# PART 2:
# download and import directory
wget -O archive.tar.gz --no-check-certificate 'https://drive.google.com/u/0/uc?id=1KRBNW33QWqbvbVHa3hLJivOAt60yukkg&export=download'
gunzip archive.tar.gz
tar xvf archive.tar
zpool import -d zpoolexport/ otus

# here you can retrive "otus" properties via the command:
# -> zfs get all otus | egrep "available|readonly|recordsize|compression|checksum"


# PART 3
# download and import snapshot
wget -O otus_task2.file --no-check-certificate "https://drive.google.com/u/0/uc?id=1gH8gCL9y7Nd5Ti3IRmplZPF1XjzxeRAG&export=download"
zfs receive otus/test@today < otus_task2.file

# to retrieve content of the file you can use the following command:
# -> cat `find /otus/ -name "secret_message"``