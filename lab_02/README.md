## LAB 02 - Работа с mdadm


### lsblk перед началом манипуляций
```bash
root@otuslinux:/home/vagrant# lsblk

NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
loop0    7:0    0 63.5M  1 loop /snap/core20/1974
loop1    7:1    0 91.9M  1 loop /snap/lxd/24061
loop2    7:2    0 53.3M  1 loop /snap/snapd/19457
sda      8:0    0   40G  0 disk 
└─sda1   8:1    0   40G  0 part /
sdb      8:16   0   10M  0 disk 
sdc      8:32   0  250M  0 disk 
sdd      8:48   0  250M  0 disk 
sde      8:64   0  250M  0 disk 
sdf      8:80   0  250M  0 disk 
sdg      8:96   0  250M  0 disk 
```

### Удаляем суперблоки
```bash
root@otuslinux:/home/vagrant# mdadm --zero-superblock --force /dev/sd{c,d,e,f,g}
mdadm: Unrecognised md component device - /dev/sdc
mdadm: Unrecognised md component device - /dev/sdd
mdadm: Unrecognised md component device - /dev/sde
mdadm: Unrecognised md component device - /dev/sdf
mdadm: Unrecognised md component device - /dev/sdg
```

### Собираем RAID 10
``` bash
root@otuslinux:/home/vagrant# mdadm --create --verbose /dev/md0 -l 10 -n 4 /dev/sd{c,d,e,f}
mdadm: layout defaults to n2
mdadm: layout defaults to n2
mdadm: chunk size defaults to 512K
mdadm: size set to 253952K
mdadm: Defaulting to version 1.2 metadata
mdadm: array /dev/md0 started.

root@otuslinux:/home/vagrant# cat /proc/mdstat 
Personalities : [linear] [multipath] [raid0] [raid1] [raid6] [raid5] [raid4] [raid10] 
md0 : active raid10 sdf[3] sde[2] sdd[1] sdc[0]
      507904 blocks super 1.2 512K chunks 2 near-copies [4/4] [UUUU]
      
unused devices: <none>

root@otuslinux:/home/vagrant# mdadm -D /dev/md0
/dev/md0:
           Version : 1.2
     Creation Time : Mon Jul 17 20:35:27 2023
        Raid Level : raid10
        Array Size : 507904 (496.00 MiB 520.09 MB)
     Used Dev Size : 253952 (248.00 MiB 260.05 MB)
      Raid Devices : 4
     Total Devices : 4
       Persistence : Superblock is persistent

       Update Time : Mon Jul 17 20:35:29 2023
             State : clean 
    Active Devices : 4
   Working Devices : 4
    Failed Devices : 0
     Spare Devices : 0

            Layout : near=2
        Chunk Size : 512K

Consistency Policy : resync

              Name : otuslinux:0  (local to host otuslinux)
              UUID : 67570eac:b8385652:bbea43b2:86ee1263
            Events : 17

    Number   Major   Minor   RaidDevice State
       0       8       32        0      active sync set-A   /dev/sdc
       1       8       48        1      active sync set-B   /dev/sdd
       2       8       64        2      active sync set-A   /dev/sde
       3       8       80        3      active sync set-B   /dev/sdf
```


### Выводим из строя одно из устройств и заменяем его на другое
``` bash
root@otuslinux:/home/vagrant# mdadm /dev/md0 --fail /dev/sdc 
root@otuslinux:/home/vagrant# cat /proc/mdstat        
Personalities : [linear] [multipath] [raid0] [raid1] [raid6] [raid5] [raid4] [raid10] 
md0 : active raid10 sdf[3] sde[2] sdd[1] sdc[0](F)                                                       
      507904 blocks super 1.2 512K chunks 2 near-copies [4/3] [_UUU]


root@otuslinux:/home/vagrant# mdadm -D /dev/md0
/dev/md0:
           Version : 1.2
     Creation Time : Mon Jul 17 20:35:27 2023
        Raid Level : raid10
        Array Size : 507904 (496.00 MiB 520.09 MB)
     Used Dev Size : 253952 (248.00 MiB 260.05 MB)
      Raid Devices : 4
     Total Devices : 4
       Persistence : Superblock is persistent

       Update Time : Mon Jul 17 20:43:25 2023
             State : clean, degraded 
    Active Devices : 3
   Working Devices : 3
    Failed Devices : 1
     Spare Devices : 0

            Layout : near=2
        Chunk Size : 512K

Consistency Policy : resync

              Name : otuslinux:0  (local to host otuslinux)
              UUID : 67570eac:b8385652:bbea43b2:86ee1263
            Events : 19

    Number   Major   Minor   RaidDevice State
       -       0        0        0      removed
       1       8       48        1      active sync set-B   /dev/sdd
       2       8       64        2      active sync set-A   /dev/sde
       3       8       80        3      active sync set-B   /dev/sdf

       0       8       32        -      faulty   /dev/sdc


# удаляем из рейда сломанное устройство
root@otuslinux:/home/vagrant# mdadm /dev/md0 --remove /dev/sdc
mdadm: hot removed /dev/sdc from /dev/md0

# добавляем новое устройство
root@otuslinux:/home/vagrant# mdadm /dev/md0 --add /dev/sdg
mdadm: added /dev/sdg

```bash
root@otuslinux:/home/vagrant# mdadm -D /dev/md0
/dev/md0:
           Version : 1.2
     Creation Time : Mon Jul 17 20:35:27 2023
        Raid Level : raid10
        Array Size : 507904 (496.00 MiB 520.09 MB)
     Used Dev Size : 253952 (248.00 MiB 260.05 MB)
      Raid Devices : 4
     Total Devices : 4
       Persistence : Superblock is persistent

       Update Time : Mon Jul 17 20:51:14 2023
             State : clean 
    Active Devices : 4
   Working Devices : 4
    Failed Devices : 0
     Spare Devices : 0

            Layout : near=2
        Chunk Size : 512K

Consistency Policy : resync

              Name : otuslinux:0  (local to host otuslinux)
              UUID : 67570eac:b8385652:bbea43b2:86ee1263
            Events : 39

    Number   Major   Minor   RaidDevice State
       4       8       96        0      active sync set-A   /dev/sdg
       1       8       48        1      active sync set-B   /dev/sdd
       2       8       64        2      active sync set-A   /dev/sde
       3       8       80        3      active sync set-B   /dev/sdf

```

### Создаем GPT таблицу на дисковом рейде и добавляем 5 разделов

```bash

root@otuslinux:/home/vagrant# parted -s /dev/md0 mklabel gpt

root@otuslinux:/home/vagrant# parted /dev/md0 mkpart primary ext4 0% 20%
Information: You may need to update /etc/fstab.

root@otuslinux:/home/vagrant# parted /dev/md0 mkpart primary ext4 20% 40% 
Information: You may need to update /etc/fstab.

root@otuslinux:/home/vagrant# parted /dev/md0 mkpart primary ext4 40% 60%
Information: You may need to update /etc/fstab.

root@otuslinux:/home/vagrant# parted /dev/md0 mkpart primary ext4 60% 80%
Information: You may need to update /etc/fstab.

root@otuslinux:/home/vagrant# parted /dev/md0 mkpart primary ext4 80% 100%
Information: You may need to update /etc/fstab.

root@otuslinux:/home/vagrant# for i in $(seq 1 5); do mkfs.ext4 /dev/md0p$i; done
mke2fs 1.45.5 (07-Jan-2020)
Creating filesystem with 25088 4k blocks and 25088 inodes

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (1024 blocks): done
Writing superblocks and filesystem accounting information: done

mke2fs 1.45.5 (07-Jan-2020)
Creating filesystem with 25344 4k blocks and 25344 inodes

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (1024 blocks): done
Writing superblocks and filesystem accounting information: done

mke2fs 1.45.5 (07-Jan-2020)
Creating filesystem with 25600 4k blocks and 25600 inodes

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (1024 blocks): done
Writing superblocks and filesystem accounting information: done

mke2fs 1.45.5 (07-Jan-2020)
Creating filesystem with 25344 4k blocks and 25344 inodes

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (1024 blocks): done
Writing superblocks and filesystem accounting information: done

mke2fs 1.45.5 (07-Jan-2020)
Creating filesystem with 25088 4k blocks and 25088 inodes

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (1024 blocks): done
Writing superblocks and filesystem accounting information: done
```


```bash
root@otuslinux:/home/vagrant# mkdir -p /raid/part{1,2,3,4,5}
root@otuslinux:/home/vagrant# for i in $(seq 1 5); do mount /dev/md0p$i /raid/part$i; done

root@otuslinux:/home/vagrant# mount | tail -n5
/dev/md0p1 on /raid/part1 type ext4 (rw,relatime,stripe=256)
/dev/md0p2 on /raid/part2 type ext4 (rw,relatime,stripe=256)
/dev/md0p3 on /raid/part3 type ext4 (rw,relatime,stripe=256)
/dev/md0p4 on /raid/part4 type ext4 (rw,relatime,stripe=256)
/dev/md0p5 on /raid/part5 type ext4 (rw,relatime,stripe=256)
```

```bash 
for i in $(seq 1 5); do echo "/dev/md0p$i /raid/part$i ext4 defaults,nofail,discard 0 0" | tee -a /etc/fstab; done
```


### Генерируем конфигурацию автосборки рейда при загрузке

```bash
root@otuslinux:/home/vagrant# echo "DEVICE partitions" > /etc/mdadm/mdadm.conf

root@otuslinux:/home/vagrant# mdadm --detail --scan --verbose 
ARRAY /dev/md0 level=raid10 num-devices=4 metadata=1.2 name=otuslinux:0 UUID=67570eac:b8385652:bbea43b2:86ee1263
   devices=/dev/sdc,/dev/sdd,/dev/sde,/dev/sdf

root@otuslinux:/home/vagrant# mdadm --detail --scan --verbose | awk '/ARRAY/ {print}'
ARRAY /dev/md0 level=raid10 num-devices=4 metadata=1.2 name=otuslinux:0 UUID=67570eac:b8385652:bbea43b2:86ee1263

root@otuslinux:/home/vagrant# mdadm --detail --scan --verbose | awk '/ARRAY/ {print}' >> /etc/mdadm/mdadm.conf 

root@otuslinux:/home/vagrant# update-initramfs -u
```