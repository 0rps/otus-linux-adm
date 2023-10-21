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

worker_index=0
host_name=""
ip=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -w)
      host_name="worker_$worker_index"
      ip="$2"
      worker_index=$((worker_index+1))
      shift 2
      ;;
    -m)
      host_name="monitoring"
      ip="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
  
  echo "$host_name ansible_host=$ip ansible_port=22 ansible_user=vagrant ansible_ssh_private_key_file=$PRIVATE_KEY_PATH" >> "$ANSIBLE_ROOT/staging/hosts"
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
