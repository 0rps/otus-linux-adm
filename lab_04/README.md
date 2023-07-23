## Работа с ZFS

Лабораторная работа состоит из 3 частей:
* Собрать zfs пул и определить лучший алгоритм сжатия для определенного файла
* Импортировать директорию и посмотреть свойства zfs директории
* Вытащить из снэпшота содержимое файла.


Все команды ниже почти полностью повторяют методичку.

### Структура директории
* `Vagrantfile` - конфигурация виртуальной машины
* `zfs_script.sh` - provision скрипт, содержит команды необходимые для выполнения всех частей лабораторной работы.


### Задание 1. Определение алгоритма с наилучшим сжатием

```bash
# Получаем список доступных томов
[root@zfs ~]# lsblk
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda      8:0    0   40G  0 disk 
-sda1   8:1    0   40G  0 part /
sdb      8:16   0  512M  0 disk 
sdc      8:32   0  512M  0 disk 
sdd      8:48   0  512M  0 disk 
sde      8:64   0  512M  0 disk 
sdf      8:80   0  512M  0 disk 
sdg      8:96   0  512M  0 disk 
sdh      8:112  0  512M  0 disk 
sdi      8:128  0  512M  0 disk 

# Собираем пул
[root@zfs ~]# zpool create otus1 mirror /dev/sdb /dev/sdc
[root@zfs ~]# zpool create otus2 mirror /dev/sdd /dev/sde
[root@zfs ~]# zpool create otus3 mirror /dev/sdf /dev/sdg
[root@zfs ~]# zpool create otus4 mirror /dev/sdh /dev/sdi

[root@zfs ~]# zpool list
NAME    SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT
otus1   480M  91.5K   480M        -         -     0%     0%  1.00x    ONLINE  -
otus2   480M  91.5K   480M        -         -     0%     0%  1.00x    ONLINE  -
otus3   480M  91.5K   480M        -         -     0%     0%  1.00x    ONLINE  -
otus4   480M  91.5K   480M        -         -     0%     0%  1.00x    ONLINE  -

# выставляем алгоритмы сжатия
[root@zfs ~]# zfs set compression=lz4 otus1
[root@zfs ~]# zfs set compression=lzjb otus1
[root@zfs ~]# zfs set compression=lz4 otus2
[root@zfs ~]# zfs set compression=gzip-9 otus3
[root@zfs ~]# zfs set compression=zle otus4

# проверка
[root@zfs ~]# zfs get all | grep compression
otus1  compression           lzjb                   local
otus2  compression           lz4                    local
otus3  compression           gzip-9                 local
otus4  compression           zle                    local

# скачиваем файл и копируем во всех zfs директории
[root@zfs ~]# wget -P ./ https://gutenberg.org/cache/epub/2600/pg2600.converter.log
--2023-07-23 19:44:07--  https://gutenberg.org/cache/epub/2600/pg2600.converter.log
Resolving gutenberg.org (gutenberg.org)... 152.19.134.47, 2610:28:3090:3000:0:bad:cafe:47
Connecting to gutenberg.org (gutenberg.org)|152.19.134.47|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 40950803 (39M) [text/plain]
Saving to: './pg2600.converter.log'
2023-07-23 19:44:59 (800 KB/s) - './pg2600.converter.log' saved [40950803/40950803]

[root@zfs ~]# for i in {1..4}; do cp ./pg2600.converter.log /otus$i/; done

# проверяем занятое пространство
[root@zfs ~]# ls -l /otus*
/otus1:
total 22052
-rw-r--r--. 1 root root 40950803 Jul 23 19:46 pg2600.converter.log

/otus2:
total 17987
-rw-r--r--. 1 root root 40950803 Jul 23 19:46 pg2600.converter.log

/otus3:
total 10956
-rw-r--r--. 1 root root 40950803 Jul 23 19:46 pg2600.converter.log

/otus4:
total 40019
-rw-r--r--. 1 root root 40950803 Jul 23 19:46 pg2600.converter.log

# победитель - gzip-9
[root@zfs ~]# zfs list
NAME    USED  AVAIL     REFER  MOUNTPOINT
otus1  21.7M   330M     21.6M  /otus1
otus2  17.7M   334M     17.6M  /otus2
otus3  10.8M   341M     10.7M  /otus3
otus4  39.2M   313M     39.1M  /otus4
```

### Определение настроек пула
```bash

# скачиваем файл и распаковываем
[root@zfs ~]# wget -O archive.tar.gz --no-check-certificate 'https://drive.google.com/u/0/uc?id=1KRBNW33QWqbvbVHa3hLJivOAt60yukkg&export=download'
--2023-07-23 19:54:25--  https://drive.google.com/u/0/uc?id=1KRBNW33QWqbvbVHa3hLJivOAt60yukkg&export=download
Resolving drive.google.com (drive.google.com)... 216.58.212.14, 2a00:1450:4017:800::200e
Connecting to drive.google.com (drive.google.com)|216.58.212.14|:443... connected.
HTTP request sent, awaiting response... 302 Found
Location: https://drive.google.com/uc?id=1KRBNW33QWqbvbVHa3hLJivOAt60yukkg&export=download [following]
--2023-07-23 19:54:26--  https://drive.google.com/uc?id=1KRBNW33QWqbvbVHa3hLJivOAt60yukkg&export=download
Reusing existing connection to drive.google.com:443.
HTTP request sent, awaiting response... 303 See Other
Location: https://doc-0c-bo-docs.googleusercontent.com/docs/securesc/ha0ro937gcuc7l7deffksulhg5h7mbp1/23610omfcj0inqpevm4uuphq9fvpbt7l/1690142025000/16189157874053420687/*/1KRBNW33QWqbvbVHa3hLJivOAt60yukkg?e=download&uuid=9df2d376-0543-4d79-8ee1-beaed011805a [following]
Warning: wildcards not supported in HTTP.
--2023-07-23 19:54:31--  https://doc-0c-bo-docs.googleusercontent.com/docs/securesc/ha0ro937gcuc7l7deffksulhg5h7mbp1/23610omfcj0inqpevm4uuphq9fvpbt7l/1690142025000/16189157874053420687/*/1KRBNW33QWqbvbVHa3hLJivOAt60yukkg?e=download&uuid=9df2d376-0543-4d79-8ee1-beaed011805a
Resolving doc-0c-bo-docs.googleusercontent.com (doc-0c-bo-docs.googleusercontent.com)... 142.251.140.65, 2a00:1450:4017:815::2001
Connecting to doc-0c-bo-docs.googleusercontent.com (doc-0c-bo-docs.googleusercontent.com)|142.251.140.65|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 7275140 (6.9M) [application/x-gzip]
Saving to: 'archive.tar.gz'

100%[===========================================================================================================================================================================>] 7,275,140   6.30MB/s   in 1.1s   

2023-07-23 19:54:33 (6.30 MB/s) - 'archive.tar.gz' saved [7275140/7275140]

[root@zfs ~]# gunzip archive.tar.gz 
[root@zfs ~]# ls
anaconda-ks.cfg  archive.tar  original-ks.cfg  pg2600.converter.log
[root@zfs ~]# tar xvf archive.tar 
zpoolexport/
zpoolexport/filea
zpoolexport/fileb
```

```bash 
# импортируем директорию в пул
[root@zfs ~]# zpool import -d zpoolexport/
   pool: otus
     id: 6554193320433390805
  state: ONLINE
 action: The pool can be imported using its name or numeric identifier.
 config:

        otus                         ONLINE
          mirror-0                   ONLINE
            /root/zpoolexport/filea  ONLINE
            /root/zpoolexport/fileb  ONLINE

[root@zfs ~]# zpool import -d zpoolexport/ otus
[root@zfs ~]# zpool status
  pool: otus          
 state: ONLINE
  scan: none requested
config:                                       
                                                     
        NAME                         STATE     READ WRITE CKSUM
        otus                         ONLINE       0     0     0
          mirror-0                   ONLINE       0     0     0
            /root/zpoolexport/filea  ONLINE       0     0     0
            /root/zpoolexport/fileb  ONLINE       0     0     0
                                                     
errors: No known data errors

# получаем свойства для определенного тома в пуле
[root@zfs ~]# zfs get all otus | egrep "available|readonly|recordsize|compression|checksum"
otus  available             350M                   -
otus  recordsize            128K                   local
otus  checksum              sha256                 local
otus  compression           zle                    local
otus  readonly              off                    default
```

### Работа со снэпшотами

```bash
# скачиваем снэпшот
[root@zfs ~]# wget -O otus_task2.file --no-check-certificate "https://drive.google.com/u/0/uc?id=1gH8gCL9y7Nd5Ti3IRmplZPF1XjzxeRAG&export=download"
--2023-07-23 20:08:53--  https://drive.google.com/u/0/uc?id=1gH8gCL9y7Nd5Ti3IRmplZPF1XjzxeRAG&export=download
Resolving drive.google.com (drive.google.com)... 142.251.140.78, 2a00:1450:4017:800::200e
Connecting to drive.google.com (drive.google.com)|142.251.140.78|:443... connected.
HTTP request sent, awaiting response... 302 Found
Location: https://drive.google.com/uc?id=1gH8gCL9y7Nd5Ti3IRmplZPF1XjzxeRAG&export=download [following]
--2023-07-23 20:08:53--  https://drive.google.com/uc?id=1gH8gCL9y7Nd5Ti3IRmplZPF1XjzxeRAG&export=download
Reusing existing connection to drive.google.com:443.
HTTP request sent, awaiting response... 303 See Other
Location: https://doc-00-bo-docs.googleusercontent.com/docs/securesc/ha0ro937gcuc7l7deffksulhg5h7mbp1/j8vlh6cucpnbj0nplr5ovjuq8s68rqup/1690142925000/16189157874053420687/*/1gH8gCL9y7Nd5Ti3IRmplZPF1XjzxeRAG?e=download&uuid=43c3d543-fc6f-43b8-bae7-2d45a0d9904e [following]
Warning: wildcards not supported in HTTP.
--2023-07-23 20:08:57--  https://doc-00-bo-docs.googleusercontent.com/docs/securesc/ha0ro937gcuc7l7deffksulhg5h7mbp1/j8vlh6cucpnbj0nplr5ovjuq8s68rqup/1690142925000/16189157874053420687/*/1gH8gCL9y7Nd5Ti3IRmplZPF1XjzxeRAG?e=download&uuid=43c3d543-fc6f-43b8-bae7-2d45a0d9904e
Resolving doc-00-bo-docs.googleusercontent.com (doc-00-bo-docs.googleusercontent.com)... 142.251.140.65, 2a00:1450:4017:80e::2001
Connecting to doc-00-bo-docs.googleusercontent.com (doc-00-bo-docs.googleusercontent.com)|142.251.140.65|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 5432736 (5.2M) [application/octet-stream]
Saving to: 'otus_task2.file'

100%[===========================================================================================================================================================================>] 5,432,736   7.21MB/s   in 0.7s   

2023-07-23 20:08:58 (7.21 MB/s) - 'otus_task2.file' saved [5432736/5432736]
```


```bash
# импортируем снэпшот в zfs
[root@zfs ~]# zfs receive otus/test@today < otus_task2.file


[root@zfs ~]# zfs list
NAME             USED  AVAIL     REFER  MOUNTPOINT
otus            4.93M   347M       25K  /otus
otus/hometask2  1.88M   347M     1.88M  /otus/hometask2
otus/test       2.83M   347M     2.83M  /otus/test
otus1           21.7M   330M     21.6M  /otus1
otus2           17.7M   334M     17.6M  /otus2
otus3           10.8M   341M     10.7M  /otus3
otus4           39.2M   313M     39.1M  /otus4

# ищем файл
[root@zfs otus]# find /otus/ -name "secret_message"
/otus/test/task1/file_mess/secret_message

# получаем содержимое искомого файла
[root@zfs otus]# cat test/task1/file_mess/secret_message 
https://github.com/sindresorhus/awesome
```


