#!/bin/bash

yum install -y rpmdevtools \
  rpm-build \
  golang \
  make \
  yum-utils \

rpmdev-setuptree
cp /tmp/files/webgostatus.spec ~/rpmbuild/SPECS
tar -C /tmp/files -cvf ~/rpmbuild/SOURCES/webgostatus-1.0.tar.gz webgostatus-1.0
rpmbuild -bb ~/rpmbuild/SPECS/webgostatus.spec

# (check) list built package
ls ~/rpmbuild/RPMS/x86_64/