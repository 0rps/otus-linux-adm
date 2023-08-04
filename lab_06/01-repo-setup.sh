#!/bin/bash
yum install -y createrepo nginx

# create repo and copy rpm package
mkdir /usr/share/nginx/html/repo
cp ~/rpmbuild/RPMS/x86_64/* /usr/share/nginx/html/repo/
createrepo /usr/share/nginx/html/repo/

# configure nginx and run it
cp -f /tmp/files/nginx.conf /etc/nginx/nginx.conf
nginx -t
systemctl start nginx

# testing
curl -a http://localhost/repo/

# adding repo
cat >> /etc/yum.repos.d/otus.repo << EOF
[otus]
name=otus-linux
baseurl=http://localhost/repo
gpgcheck=0
enabled=1
EOF

# checking the repo
yum repolist enabled | grep otus
yum list | grep otus

# install bullt package and test it
yum install -y webgostatus
webgostatus &
sleep 1
curl http://localhost:7080
pkill webgostatus
