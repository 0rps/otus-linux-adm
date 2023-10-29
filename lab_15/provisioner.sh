# Allow password authentication (for Ubuntu 23.04 image this is disabled by default and located in /etc/ssh/sshd_config.d/60-cloudimg-settings.conf)
sed -i 's/^PasswordAuthentication.*$/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
systemctl restart ssh.service

# Add 'otusadm' and 'otus' users with password 'Otus2023!'
useradd otusadm && useradd otus
echo -e 'Otus2023!\nOtus2023!' | passwd otusadm
echo -e 'Otus2023!\nOtus2023!' | passwd otus

# Add 'otusadm','root','vagrant' to 'admin' group
groupadd -f admin
echo -n "otusadm;root;vagrant" | xargs -d ';' -I {} usermod {} -a -G admin

# Add pam rule to disable login for simple users on weekends
sudo cp /vagrant/files/login.sh /usr/local/bin/login.sh
chmod +x /usr/local/bin/login.sh
echo "auth required pam_exec.so debug /usr/local/bin/login.sh" >> /etc/pam.d/sshd

# Install docker
apt-get update && apt-get install -y docker.io

# Add 'otus' user to 'docker' group to allow run docker container without sudo
usermod otus -a -G docker

# Add rule for polkit to allow 'otus' user to manage docker service
cat << EOF > /etc/polkit-1/rules.d/00-otus-docker.rules
polkit.addRule(function(action, subject) {
  if (
    action.id == "org.freedesktop.systemd1.manage-units" &&
    action.lookup("unit") == "docker.service"  &&
    subject.user == "otus"
  )
  {
    polkit.log("Custom rule for 'otus' user to manage docker service is triggered")
    return polkit.Result.YES;
  }
})
EOF

sed 's/--no-debug//g' /usr/lib/systemd/system/polkit.service > /tmp/polkit.service
cp -f /tmp/polkit.service /usr/lib/systemd/system/polkit.service
systemctl daemon-reload
systemctl restart polkit.service
