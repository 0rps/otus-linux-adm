#!/bin/bash

apt update
apt install -y tmux mc php php-cli apache2 libapache2-mod-fcgid spawn-fcgi php-cgi

mkdir /etc/sysconfig

### spawn-fcgi
# configure spawn-fcgi service
cp /tmp/fcgi_service/spawn-fcgi /etc/sysconfig
cp /tmp/fcgi_service/spawn-fcgi.service /etc/systemd/system/

# there is no 'apache' user and corresponding group
groupadd apache
useradd -g apache -G www-data apache

#### watchlog 
# prepare watchlog service config 
cp /tmp/watchlog_service/watchlog /etc/sysconfig/
cp /tmp/watchlog_service/watchlog.sh /opt/

# make script executable
chmod +x /opt/watchlog.sh

# copy service files
cp /tmp/watchlog_service/watchlog.service /etc/systemd/system/
cp /tmp/watchlog_service/watchlog.timer /etc/systemd/system/

### apache2
mkdir -p /etc/apache2-custom/first/mods
mkdir -p /etc/apache2-custom/second/mods

cp /etc/apache2/mods-available/mpm_prefork.load /etc/apache2-custom/first/mods/mpm_prefork.load
cp /etc/apache2/mods-available/mpm_prefork.load /etc/apache2-custom/second/mods/mpm_prefork.load

cp /tmp/apache2/apache2-first /etc/apache2-custom/first/apache2.conf
cp /tmp/apache2/apache2-second /etc/apache2-custom/second/apache2.conf

cp -f /tmp/apache2/apache2.service /usr/lib/systemd/system/apache2@.service

### reload and stop services
systemctl daemon-reload
systemctl disable apache2 
systemctl stop apache2 

