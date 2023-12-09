#!/bin/bash

apt update
apt install vim iperf3 openvpn -y 

openvpn --genkey secret /etc/openvpn/static.key
cp /etc/openvpn/static.key /vagrant/

tee -a /etc/openvpn/server.conf <<EOF
dev tap
ifconfig 10.10.10.1 255.255.255.0,
providers legacy default
topology subnet
secret /etc/openvpn/static.key
comp-lzo
status /var/log/openvpn-status.log
log /var/log/openvpn.log
verb 3
EOF

tee -a /etc/systemd/system/openvpn@.service <<EOF
[Unit]
Description=OpenVPN Tunneling Application On %I
After=network.target

[Service]
Type=notify
PrivateTmp=true
ExecStart=/usr/sbin/openvpn --cd /etc/openvpn/ --config %i.conf

[Install]
WantedBy=multi-user.target
EOF

systemctl start openvpn@server
systemctl enable openvpn@server

