# Vagrant стенд для NFS

### Цель
Научиться самостоятельно развернуть сервис NFS и подключить к нему клиента 

### Структура файлов
* `Vagrantfile` - конфигурация для Vagrant с описанием двух виртуальных машин: `nfss` (192.168.56.10) и `nfsc` (192.168.56.11).
* `nfsc_script.sh` - provision скрипт для "серверной" виртуальной машины
* `nfsc_script.sh` - provision скрипт для "клиентской" виртуальной машины

Скрипты разбиты на блоки, каждый из которых имеет небольшой комментарий.
Из скриптов убраны все диагностические блоки, а также reload systemctl модулей, т.к. каждый скрипт завершается командой `reboot`.

### Диагностика после выполнения `vagrant up`

##### Состояние nfs настроек/сервисов на сервере
```bash
➜  lab_05 git:(lab_05) ✗ vagrant ssh nfss
Last login: Sun Jul 23 14:35:13 2023 from 10.0.2.2

# nfs работает
[vagrant@nfss ~]$ systemctl status nfs
● nfs-server.service - NFS server and services
   Loaded: loaded (/usr/lib/systemd/system/nfs-server.service; enabled; vendor preset: disabled)
  Drop-In: /run/systemd/generator/nfs-server.service.d
           └─order-with-mounts.conf
   Active: active (exited) since Sun 2023-07-23 14:27:57 UTC; 8min ago
  Process: 835 ExecStartPost=/bin/sh -c if systemctl -q is-active gssproxy; then systemctl reload gssproxy ; fi (code=exited, status=0/SUCCESS)
  Process: 807 ExecStart=/usr/sbin/rpc.nfsd $RPCNFSDARGS (code=exited, status=0/SUCCESS)
  Process: 805 ExecStartPre=/usr/sbin/exportfs -r (code=exited, status=0/SUCCESS)
 Main PID: 807 (code=exited, status=0/SUCCESS)
   CGroup: /system.slice/nfs-server.service

# firewall работает
[vagrant@nfss ~]$ systemctl status firewalld
● firewalld.service - firewalld - dynamic firewall daemon
   Loaded: loaded (/usr/lib/systemd/system/firewalld.service; enabled; vendor preset: enabled)
   Active: active (running) since Sun 2023-07-23 14:27:54 UTC; 8min ago
     Docs: man:firewalld(1)
 Main PID: 408 (firewalld)
   CGroup: /system.slice/firewalld.service
           └─408 /usr/bin/python2 -Es /usr/sbin/firewalld --nofork --nopid

# настройки расшаренной директории валидны
[vagrant@nfss ~]$ sudo exportfs -s
/srv/share  192.168.56.11/32(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,root_squash,no_all_squash)

[vagrant@nfss ~]$ sudo showmount -a 192.168.56.10
All mount points on 192.168.56.10:
192.168.56.11:/srv/share
```

##### Состояние nfs настроек/сервисов на клиенте

```bash
➜  lab_05 git:(lab_05) ✗ vagrant ssh nfsc
Last login: Sun Jul 23 14:30:20 2023 from 10.0.2.2

[vagrant@nfsc ~]$ sudo showmount -a 192.168.56.10
All mount points on 192.168.56.10:
192.168.56.11:/srv/share

# директория смонтирова, удаленный адрес совпадает с адресом сервера
[vagrant@nfsc ~]$ mount | grep mnt
systemd-1 on /mnt type autofs (rw,relatime,fd=21,pgrp=1,timeout=0,minproto=5,maxproto=5,direct,pipe_ino=10876)
192.168.56.10:/srv/share/ on /mnt type nfs (rw,relatime,vers=3,rsize=32768,wsize=32768,namlen=255,hard,proto=udp,timeo=11,retrans=3,sec=sys,mountaddr=192.168.56.10,mountvers=3,mountport=20048,mountproto=udp,local_lock=none,addr=192.168.56.10)
```

##### Проверка доступов
Создадим в расшаренной директории `upload` файл с сервера и с клиента и проверим, что оба видны с двух узлов.

```bash
# Создаем файл с сервера
[vagrant@nfss ~]$ touch /srv/share/upload/create_by_server

# Создаем файл с клиента
[vagrant@nfsc ~]$ touch /mnt/upload/created_by_client

# Проверяем, что с сервера видны оба файла
[vagrant@nfss ~]$ ls -al /srv/share/upload/
total 0
drwxrwxrwx. 2 nfsnobody nfsnobody 55 Jul 23 14:38 .
drwxr-xr-x. 3 nfsnobody nfsnobody 20 Jul 23 14:27 ..
-rw-rw-r--. 1 vagrant   vagrant    0 Jul 23 14:37 create_by_server
-rw-rw-r--. 1 vagrant   vagrant    0 Jul 23 14:38 created_by_client

# Проверяем, что с клиента видны оба файла
[vagrant@nfsc ~]$ ls -al /mnt/upload
total 0
drwxrwxrwx. 2 nfsnobody nfsnobody 55 Jul 23 14:38 .
drwxr-xr-x. 3 nfsnobody nfsnobody 20 Jul 23 14:27 ..
-rw-rw-r--. 1 vagrant   vagrant    0 Jul 23 14:37 create_by_server
-rw-rw-r--. 1 vagrant   vagrant    0 Jul 23 14:38 created_by_client
```

**NOTE:** обе виртуальные машины были перезагружены с самого начала, поэтому нет необходимости в еще одной перезагрузке и проверке. 