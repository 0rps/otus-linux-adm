#!/bin/bash

apt update 
apt install vim openvpn easy-rsa -y 

tee -a /etc/openvpn/server.conf <<EOF
port 1207
proto udp
dev tun
ca /etc/openvpn/pki/ca.crt
cert /etc/openvpn/pki/issued/server.crt
key /etc/openvpn/pki/private/server.key
dh /etc/openvpn/pki/dh.pem

server 10.10.10.0 255.255.255.0
push "route 10.10.10.0 255.255.255.0"
ifconfig-pool-persist ipp.txt
client-to-client
keepalive 10 120
comp-lzo
persist-key
persist-tun
status /var/log/openvpn-status.log

log /var/log/openvpn.log

verb 3
EOF
 
cd /etc/openvpn/
/usr/share/easy-rsa/easyrsa init-pki
echo 'rasvpn' | /usr/share/easy-rsa/easyrsa build-ca nopass
echo 'rasvpn' | /usr/share/easy-rsa/easyrsa gen-req server nopass
echo 'yes' | /usr/share/easy-rsa/easyrsa sign-req server server
/usr/share/easy-rsa/easyrsa gen-dh
openvpn --genkey secret ca.key

echo 'client' | /usr/share/easy-rsa/easyrsa gen-req client nopass
echo 'yes' | /usr/share/easy-rsa/easyrsa sign-req client client

cp /etc/openvpn/pki/ca.crt /vagrant/client/
cp /etc/openvpn/pki/issued/client.crt /vagrant/client/
cp /etc/openvpn/pki/private/client.key /vagrant/client/

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