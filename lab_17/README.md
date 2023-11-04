# Резервное копирование

### Задание

* Настроить стенд Vagrant с двумя виртуальными машинами: backup_server и client
* Настроить удаленный бэкап каталога /etc c сервера client при помощи borgbackup

### Конфигурация инфраструктуры

Конфигурируем 2 машины:
* `client`
* `server`

Для `server` создадим отдельный диск, который будет использоваться дальше в качестве точки монтирования `/var/backup`.
```bash
:scsi2 => {
  :dfile => home + '/VirtualBox VMs/otus_17/disks/scsi2.vdi',
  :size => 2048,
  :port => 2
},
```

А в качестве базового `provisioning` части для `client` и `server` будут использованы следующие команды:
```bash
apt-get update
apt-get install ansible -y  

cd /vagrant
ansible-playbook -i="#{boxname}," -c local ./playbook.yml
```

Полная конфигурация `Vagrantfile` [здесь](./Vagrantfile).

### Настройка `server` хоста

Ниже приведены блоки `Ansible` конфигурации:

1) Создание пользователя `borg`;
```yaml
  - name: Create borg user
    user:
      name: borg
      shell: /bin/bash
      home: /home/borg
      createhome: yes
      state: present
```

2) Конфигурация отдельного диска для `/var/backup` точки монтирования;
```yaml
  - name: Create a new primary partition
    parted:
      device: /dev/sdc
      number: 1
      state: present
    when: lsblk_out.stdout == "no"

  - name: Format partition 
    filesystem:
      fstype: ext4
      dev: /dev/sdc1
    when: lsblk_out.stdout == "no"

  - name: Get partition UUID
    command: lsblk /dev/sdc1 -no UUID
    register: sdc_uuid

  - name: Mount partition 
    mount:
      path: /var/backup
      src: /dev/sdc1
      fstype: ext4
      opts: defaults
      state: mounted
    when: lsblk_out.stdout == "no"
  
  - name: Add to fstab
    lineinfile:
      path: /etc/fstab
      line: UUID={{ sdc_uuid.stdout }} /var/backup ext4 defaults 0 0
    when: lsblk_out.stdout == "no"
```

3) Добавление публичного ключа для ssh доступа с `client` хоста
4) Создание необходимых директорий и изменение прав доступа

```yaml
  - name: Create .ssh directory
    file:
      path: /home/borg/.ssh
      state: directory
      owner: borg
      group: borg
      mode: 0700

  - name: Copy public SSH key
    copy:
      src: /vagrant/files/ssh/key.pub
      dest: /home/borg/.ssh/authorized_keys
      owner: borg
      group: borg
      mode: 0600

  - name: Create backup directory
    file:
      path: /var/backup
      state: directory
      owner: borg
      group: borg
      mode: 0700
```

### Настройка `client` хоста

1) Настройка SSH

```yaml
  - name: Create .ssh directory
    file:
      path: /root/.ssh
      state: directory
      owner: root
      group: root
      mode: 0700
  - name: Copy private SSH key
    copy:
      src: files/ssh/key
      dest: /root/.ssh/
      owner: root
      group: root
      mode: 0600
  - name: Copy public SSH key
    copy:
      src: files/ssh/key.pub
      dest: /root/.ssh/
      owner: root
      group: root
      mode: 0644
  
  - name: Set default identity
    shell: echo "IdentityFile /root/.ssh/key" > /root/.ssh/config
  
  - name: Add known_hosts
    shell: ssh-keyscan -H {{ backup_host }} > /root/.ssh/known_hosts
```

2) Добавление `unit` файлов и перезапуск `systemd`

```yaml
  - name: Generate Unit files
    template: 
      src: "{{ item.src }}" 
      dest: "{{ item.dest }}"
      owner: root
      group: root
      mode: 0640
    loop:
      - src: /vagrant/files/units/borg-run.service.j2
        dest: /etc/systemd/system/borg-run.service
      - src: /vagrant/files/units/borg-run.timer.j2
        dest: /etc/systemd/system/borg-run.timer
      - src: /vagrant/files/units/borg-prune.service.j2
        dest: /etc/systemd/system/borg-prune.service
      - src: /vagrant/files/units/borg-prune.timer.j2
        dest: /etc/systemd/system/borg-prune.timer
  
  - name: Reload systemd
    systemd:
      daemon_reload: true
  
  - name: Borg backup timer service 
    systemd:
      name: borg-run.timer
      enabled: true
      state: restarted
  
  - name: Borg backup timer service 
    systemd:
      name: borg-prune.timer
      enabled: true
      state: restarted
```

3) Инициализация `borg`

```yaml
  - name: Borg init 
    shell: BORG_PASSPHRASE={{ backup_password }} borg init --encryption=repokey borg@{{ backup_host }}:/var/backup/
```

В качестве `backup` `unit` файла использована следующая конфигурация:
```bash
[Unit]
Description=Borg Backup

[Service]
Type=oneshot

Environment=BORG_PASSPHRASE={{ backup_password }}
Environment=REPO=borg@{{ backup_host }}:/var/backup/
Environment=BACKUP_TARGET=/etc

ExecStart=/bin/borg create --stats ${REPO}::etc-{now:%%Y-%%m-%%d_%%H:%%M:%%S} ${BACKUP_TARGET}
```

В качестве `prune` `unit` файла использована следующая конфигурация:
```bash
[Unit]
Description=Borg Backup

[Service]
Type=oneshot

Environment=BORG_PASSPHRASE={{ backup_password }}
Environment=REPO=borg@{{ backup_host }}:/var/backup/
Environment=BACKUP_TARGET=/etc

ExecStart=/bin/borg prune \
    --keep-daily  90      \
    --keep-monthly 12     \
    --keep-yearly  1       \
    ${REPO}

```

### Проверка работы бэкапа

##### Для начала внесем изменения в /etc/hosts

```bash
root@client:/# date
Sat Nov  4 12:57:41 PM UTC 2023

root@client:/# cat /etc/hosts
127.0.0.1       localhost
# here is the new end
```

###### Посмотрим на логи borg

journalctl -u borg-run.service:
```bash

Nov 04 12:45:35 client borg[11764]: ------------------------------------------------------------------------------
Nov 04 12:45:35 client borg[11764]: Repository: ssh://borg@192.168.57.15/var/backup
Nov 04 12:45:35 client borg[11764]: Archive name: etc-2023-11-04_12:45:32
Nov 04 12:45:35 client borg[11764]: Archive fingerprint: a0990104bddc18012d41fc1e2003d4ca06d4aa035f2aed37baae3580eb7d4334
Nov 04 12:45:35 client borg[11764]: Time (start): Sat, 2023-11-04 12:45:34
Nov 04 12:45:35 client borg[11764]: Time (end):   Sat, 2023-11-04 12:45:35
Nov 04 12:45:35 client borg[11764]: Duration: 0.94 seconds
Nov 04 12:45:35 client borg[11764]: Number of files: 773
Nov 04 12:45:35 client borg[11764]: Utilization of max. archive size: 0%
Nov 04 12:45:35 client borg[11764]: ------------------------------------------------------------------------------
Nov 04 12:45:35 client borg[11764]:                        Original size      Compressed size    Deduplicated size
Nov 04 12:45:35 client borg[11764]: This archive:                2.27 MB            991.44 kB            965.10 kB
Nov 04 12:45:35 client borg[11764]: All archives:                2.27 MB            990.83 kB              1.04 MB
Nov 04 12:45:35 client borg[11764]:                        Unique chunks         Total chunks
Nov 04 12:45:35 client borg[11764]: Chunk index:                     741                  766
Nov 04 12:45:35 client borg[11764]: ------------------------------------------------------------------------------
Nov 04 12:45:35 client systemd[1]: borg-run.service: Deactivated successfully.
Nov 04 12:45:35 client systemd[1]: Finished borg-run.service - Borg Backup.
Nov 04 12:45:35 client systemd[1]: borg-run.service: Consumed 1.350s CPU time.
Nov 04 12:50:54 client systemd[1]: Starting borg-run.service - Borg Backup...
Nov 04 12:50:56 client borg[11813]: ------------------------------------------------------------------------------
Nov 04 12:50:56 client borg[11813]: Repository: ssh://borg@192.168.57.15/var/backup
Nov 04 12:50:56 client borg[11813]: Archive name: etc-2023-11-04_12:50:54
Nov 04 12:50:56 client borg[11813]: Archive fingerprint: bb252ca56cef1b30e7aef2e0af3af070f35c291b44e479a93edfcbef698906d0
Nov 04 12:50:56 client borg[11813]: Time (start): Sat, 2023-11-04 12:50:56
Nov 04 12:50:56 client borg[11813]: Time (end):   Sat, 2023-11-04 12:50:56
Nov 04 12:50:56 client borg[11813]: Duration: 0.17 seconds
Nov 04 12:50:56 client borg[11813]: Number of files: 773
Nov 04 12:50:56 client borg[11813]: Utilization of max. archive size: 0%
Nov 04 12:50:56 client borg[11813]: ------------------------------------------------------------------------------
Nov 04 12:50:56 client borg[11813]:                        Original size      Compressed size    Deduplicated size
Nov 04 12:50:56 client borg[11813]: This archive:                2.27 MB            991.44 kB                605 B
Nov 04 12:50:56 client borg[11813]: All archives:                4.54 MB              1.98 MB              1.04 MB
Nov 04 12:50:56 client borg[11813]:                        Unique chunks         Total chunks
Nov 04 12:50:56 client borg[11813]: Chunk index:                     742                 1532
Nov 04 12:50:56 client borg[11813]: ------------------------------------------------------------------------------
Nov 04 12:50:56 client systemd[1]: borg-run.service: Deactivated successfully.
Nov 04 12:50:56 client systemd[1]: Finished borg-run.service - Borg Backup.
```

###### Выберем бэкап и восстановим /etc/hosts

```bash
root@client:/# borg extract borg@192.168.57.15:/var/backup/::etc-2023-11-04_12:45:32 etc/hosts
Enter passphrase for key ssh://borg@192.168.57.15/var/backup: 

root@client:/# date
Sat Nov  4 12:58:31 PM UTC 2023

root@client:/# cat /etc/hosts
127.0.0.1       localhost

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost   ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
127.0.1.1       ubuntu-mantic   ubuntu-mantic

127.0.2.1 client client
```
