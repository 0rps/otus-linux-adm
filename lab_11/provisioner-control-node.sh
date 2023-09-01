#!/bin/bash

PRIVATE_KEY_PATH=/home/vagrant/.ssh/ansible
ANSIBLE_ROOT=/home/vagrant/ansible

# install all python modules
apt-get update
apt-get install -y ansible 

# setup SSH access for ansible
mkdir -p /home/vagrant/.ssh/
cp /tmp/keys/ansible "$PRIVATE_KEY_PATH"
cp /tmp/keys/ansible.pub "$PRIVATE_KEY_PATH.pub"

chmod 644 "$PRIVATE_KEY_PATH.pub"
chmod 600 "$PRIVATE_KEY_PATH"

# create ansible directory and staging directory with hosts
mkdir -p "$ANSIBLE_ROOT/staging"

cp -r /tmp/playbooks/* "$ANSIBLE_ROOT"

# touch file with script for adding fingerprints
echo "#!/bin/bash" > "$ANSIBLE_ROOT/add_fingerprints.sh"
chmod +x "$ANSIBLE_ROOT/add_fingerprints.sh"

# create inventory file and script for adding fingerprints
index=0
for ip in $*; do
    echo "nginx_$index ansible_host=$ip ansible_port=22 ansible_user=vagrant ansible_ssh_private_key_file=$PRIVATE_KEY_PATH" >> "$ANSIBLE_ROOT/staging/hosts"
    ((index++))

    echo "ssh-keyscan -H $ip" >> "$ANSIBLE_ROOT/add_fingerprints.sh"
done

# create ansible.cfg
tee -a "$ANSIBLE_ROOT/ansible.cfg" <<EOF
[defaults]
inventory = staging/hosts
remote_user = vagrant
host_key_checking = False
retry_files_enabled = False
EOF

chown -R vagrant:vagrant /home/vagrant
