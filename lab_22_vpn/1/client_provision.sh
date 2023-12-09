#!/bin/bash

apt update 
apt install vim openvpn iperf3 -y

tee -a /etc/openvpn/server.conf <<EOF
dev tap
remote 192.168.56.10
ifconfig 10.10.10.2 255.255.255.0
topology subnet
route 192.168.56.0 255.255.255.0
secret /etc/openvpn/static.key
comp-lzo
providers legacy default
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

cp /vagrant/static.key /etc/openvpn/

systemctl start openvpn@server
systemctl enable openvpn@server