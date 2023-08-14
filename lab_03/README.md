# Работа с LVM

**Цель** - научиться работать с логическими томами

### 01. Уменьшение `/` тома до 8GB

**Создание временного раздела из `/dev/sdb`**
```bash

[root@lvm ~]# lsblk
NAME   MAJ:MIN RM SIZE RO TYPE MOUNTPOINT
sda      8:0    0  40G  0 disk 
└─sda1   8:1    0  40G  0 part /
sdb      8:16   0  10G  0 disk 
sdc      8:32   0   2G  0 disk 
sdd      8:48   0   1G  0 disk 
sde      8:64   0   1G  0 disk 

[root@lvm ~]# pvcreate /dev/sdb
  Physical volume "/dev/sdb" successfully created.

[root@lvm ~]# vgcreate vg_root /dev/sdb
  Volume group "vg_root" successfully created

[root@lvm ~]# lvcreate -n lv_root -l +100%FREE /dev/vg_root
  Logical volume "lv_root" created.

[root@lvm ~]# mkfs.xfs /dev/vg_root/lv_root
meta-data=/dev/vg_root/lv_root   isize=512    agcount=4, agsize=655104 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=0, sparse=0
data     =                       bsize=4096   blocks=2620416, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal log           bsize=4096   blocks=2560, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
```

**Копирование файловой системы и монтирование необходимых директорий в `lv_root`**
```bash

[root@lvm ~]# mount /dev/vg_root/lv_root /mnt
[root@lvm ~]# xfsdump -J - /dev/sda1 | xfsrestore -J - /mnt
xfsrestore: using file dump (drive_simple) strategy
xfsrestore: version 3.1.7 (dump format 3.0)
xfsdump: using file dump (drive_simple) strategy
xfsdump: version 3.1.7 (dump format 3.0)
xfsdump: level 0 dump of lvm:/
xfsdump: dump date: Sun Aug 13 15:06:52 2023
xfsdump: session id: a508fcec-297a-4713-987b-a34ca9ed5594
xfsdump: session label: ""
xfsdump: ino map phase 1: constructing initial dump list
xfsdump: ino map phase 2: skipping (no pruning necessary)
xfsdump: ino map phase 3: skipping (only one dump stream)
xfsdump: ino map construction complete
xfsdump: estimated dump size: 3353668992 bytes
xfsdump: creating dump session media file 0 (media 0, file 0)
xfsdump: dumping ino map
xfsdump: dumping directories
xfsrestore: searching media for dump
xfsrestore: examining media file 0
xfsrestore: dump description: 
xfsrestore: hostname: lvm
xfsrestore: mount point: /
xfsrestore: volume: /dev/sda1
xfsrestore: session time: Sun Aug 13 15:06:52 2023
xfsrestore: level: 0
xfsrestore: session label: ""
xfsrestore: media label: ""
xfsrestore: file system id: 1c419d6c-5064-4a2b-953c-05b2c67edb15
xfsrestore: session id: a508fcec-297a-4713-987b-a34ca9ed5594
xfsrestore: media id: ec130612-2497-4601-8f77-f141010fb7e4
xfsrestore: searching media for directory dump
xfsrestore: reading directories
xfsdump: dumping non-directory files
xfsrestore: 2966 directories and 31947 entries processed
xfsrestore: directory post-processing
xfsrestore: restoring non-directory files
xfsdump: ending media file
xfsdump: media file size 3316490408 bytes
xfsdump: dump size (non-dir files) : 3297933464 bytes
xfsdump: dump complete: 10 seconds elapsed
xfsdump: Dump Status: SUCCESS
xfsrestore: restore complete: 10 seconds elapsed
xfsrestore: Restore Status: SUCCESS

[root@lvm ~]# for i in /proc/ /sys/ /dev/ /run/ /boot/; do mount --bind $i /mnt/$i; done
[root@lvm ~]# chroot /mnt
```

**Генерация конфигурации для загрузки системы с временного тома**
```bash

### добавим rd.lvm.lv=vg_root/lv_root в /etc/default/grub
[root@lvm boot]# sed -i 's/GRUB_CMDLINE_LINUX="/&rd.lvm.lv=vg_root\/lv_root /' /etc/default/grub

### генерируем initrd
[root@lvm boot]# cd /boot ; for i in `ls initramfs-*img`; do dracut -v $i `echo $i|sed "s/initramfs-//g; s/.img//g"` --force; done                                                            
Executing: /sbin/dracut -v initramfs-3.10.0-1127.el7.x86_64.img 3.10.0-1127.el7.x86_64 --force
dracut module 'busybox' will not be installed, because command 'busybox' could not be found!
dracut module 'plymouth' will not be installed, because command 'plymouthd' could not be found!
dracut module 'plymouth' will not be installed, because command 'plymouth' could not be found!
dracut module 'crypt' will not be installed, because command 'cryptsetup' could not be found!
dracut module 'dmraid' will not be installed, because command 'dmraid' could not be found!
dracut module 'dmsquash-live-ntfs' will not be installed, because command 'ntfs-3g' could not be found!
dracut module 'mdraid' will not be installed, because command 'mdadm' could not be found!
dracut module 'multipath' will not be installed, because command 'multipath' could not be found!
dracut module 'busybox' will not be installed, because command 'busybox' could not be found!
dracut module 'crypt' will not be installed, because command 'cryptsetup' could not be found!
dracut module 'dmraid' will not be installed, because command 'dmraid' could not be found!
dracut module 'dmsquash-live-ntfs' will not be installed, because command 'ntfs-3g' could not be found!
dracut module 'mdraid' will not be installed, because command 'mdadm' could not be found!
dracut module 'multipath' will not be installed, because command 'multipath' could not be found!
*** Including module: bash ***
*** Including module: nss-softokn ***
*** Including module: i18n ***
*** Including module: dm ***
Skipping udev rule: 64-device-mapper.rules
Skipping udev rule: 60-persistent-storage-dm.rules
Skipping udev rule: 55-dm.rules
*** Including module: kernel-modules ***
Omitting driver floppy
*** Including module: lvm ***
Skipping udev rule: 64-device-mapper.rules
Skipping udev rule: 56-lvm.rules
Skipping udev rule: 60-persistent-storage-lvm.rules
*** Including module: qemu ***
*** Including module: rootfs-block ***
*** Including module: terminfo ***
*** Including module: udev-rules ***
Skipping udev rule: 40-redhat-cpu-hotplug.rules
Skipping udev rule: 91-permissions.rules
*** Including module: biosdevname ***
*** Including module: systemd ***
*** Including module: usrmount ***
*** Including module: base ***
*** Including module: fs-lib ***
*** Including module: shutdown ***
*** Including modules done ***
*** Installing kernel module dependencies and firmware ***
*** Installing kernel module dependencies and firmware done ***
*** Resolving executable dependencies ***
*** Resolving executable dependencies done***
*** Hardlinking files ***
*** Hardlinking files done ***
*** Stripping files ***
*** Stripping files done ***
*** Generating early-microcode cpio image contents ***
*** No early-microcode cpio image needed ***
*** Store current command line parameters ***
*** Creating image file ***
*** Creating image file done ***
*** Creating initramfs image file '/boot/initramfs-3.10.0-1127.el7.x86_64.img' done ***

### генерируем grub файл
[root@lvm boot]# grub2-mkconfig -o /boot/grub2/grub.cfg
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-3.10.0-1127.el7.x86_64
Found initrd image: /boot/initramfs-3.10.0-1127.el7.x86_64.img
Found CentOS Linux release 7.8.2003 (Core) on /dev/mapper/vg_root-lv_root
done

### перезагружаемся
[root@lvm boot]# reboot

### проверяем точки монтирования
NAME              MAJ:MIN RM SIZE RO TYPE MOUNTPOINT
sda                 8:0    0  40G  0 disk 
└─sda1              8:1    0  40G  0 part 
sdb                 8:16   0  10G  0 disk 
└─vg_root-lv_root 253:0    0  10G  0 lvm  /
sdc                 8:32   0   2G  0 disk 
sdd                 8:48   0   1G  0 disk 
sde                 8:64   0   1G  0 disk 
```

**Перемещение `/boot` на отдельный том**
Как можно было увидеть ранее из вывода команды `lsblk`, вся система целиком расположена на `/dev/sda1`. Необходимо удалить раздел и создать два новых: под `/boot` и под lvm pv.

```bash
### Разделить /dev/sda на два раздела
[root@lvm ~]# fdisk /dev/sda
Welcome to fdisk (util-linux 2.23.2).

Changes will remain in memory only, until you decide to write them.
Be careful before using the write command.


Command (m for help): d
Selected partition 1
Partition 1 is deleted

Command (m for help): n
Partition type:
   p   primary (0 primary, 0 extended, 4 free)
   e   extended
Select (default p): 
Using default response p
Partition number (1-4, default 1): 
First sector (2048-83886079, default 2048): 
Using default value 2048
Last sector, +sectors or +size{K,M,G} (2048-83886079, default 83886079): +1G
Partition 1 of type Linux and of size 1 GiB is set

Command (m for help): a
Selected partition 1

Command (m for help): n
Partition type:
   p   primary (1 primary, 0 extended, 3 free)
   e   extended
Select (default p): 
Using default response p
Partition number (2-4, default 2): 
First sector (2099200-83886079, default 2099200): 
Using default value 2099200
Last sector, +sectors or +size{K,M,G} (2099200-83886079, default 83886079): 
Using default value 83886079
Partition 2 of type Linux and of size 39 GiB is set

Command (m for help): p

Disk /dev/sda: 42.9 GB, 42949672960 bytes, 83886080 sectors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disk label type: dos
Disk identifier: 0x0009ef1a

   Device Boot      Start         End      Blocks   Id  System
/dev/sda1   *        2048     2099199     1048576   83  Linux
/dev/sda2         2099200    83886079    40893440   83  Linux

Command (m for help): w
The partition table has been altered!

Calling ioctl() to re-read partition table.
Syncing disks.

[root@lvm ~]# mkfs.xfs -f /dev/sda1 
meta-data=/dev/sda1              isize=512    agcount=4, agsize=65536 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=0, sparse=0
data     =                       bsize=4096   blocks=262144, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal log           bsize=4096   blocks=2560, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0

### Копируем файлы, добавляем раздел в fstab и генерируем grub.cfg
[root@lvm ~]# mount /dev/sda1 /mnt
[root@lvm ~]# cp -r /boot/* /mnt/
[root@lvm ~]# rm -rf /boot/*
[root@lvm ~]# umount /dev/sda1
[root@lvm ~]# mount /dev/sda1 /boot
[root@lvm ~]# echo "`blkid | grep sda1 | awk '{print $2}'` /boot xfs defaults 0 0" >> /etc/fstab
[root@lvm ~]# grub2-mkconfig -o /boot/grub2/grub.cfg
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-3.10.0-1127.el7.x86_64
Found initrd image: /boot/initramfs-3.10.0-1127.el7.x86_64.img
done

### удалим монтирование "/" раздела в  в /etc/fstab
[root@lvm boot]# vi /etc/fstab

[root@lvm ~]# grub2-install /dev/sda
Installing for i386-pc platform.
Installation finished. No error reported.

[root@lvm ~]# reboot
```

**Уменьшение основного тома**
```bash

### Создание lvm тома

[root@lvm vagrant]# pvcreate /dev/sda2
WARNING: dos signature detected on /dev/sda2 at offset 510. Wipe it? [y/n]: y
  Wiping dos signature on /dev/sda2.
  Physical volume "/dev/sda" successfully created.
[root@lvm ~]# vgcreate VolGroup00 /dev/sda2
  Volume group "VolGroup00" successfully created
[root@lvm ~]# lvcreate -n VolGroup00/LogVol00 -L 8G /dev/VolGroup00
  Logical volume "LogVol00" created.
```

**Копирование файлов с временного тома**
```bash
[root@lvm ~]# mkfs.xfs /dev/VolGroup00/LogVol00
meta-data=/dev/VolGroup00/LogVol00 isize=512    agcount=4, agsize=524288 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=0, sparse=0
data     =                       bsize=4096   blocks=2097152, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal log           bsize=4096   blocks=2560, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0


[root@lvm ~]# mount /dev/VolGroup00/LogVol00 /mnt
[root@lvm ~]# xfsdump -J - /dev/vg_root/lv_root | xfsrestore -J - /mnt
xfsrestore: using file dump (drive_simple) strategy
xfsrestore: version 3.1.7 (dump format 3.0)
xfsdump: using file dump (drive_simple) strategy
xfsdump: version 3.1.7 (dump format 3.0)
xfsdump: level 0 dump of lvm:/
xfsdump: dump date: Mon Aug 14 12:07:58 2023
xfsdump: session id: bde4fe3b-c89a-4505-bb6d-7e7195fdaa78
xfsdump: session label: ""
xfsrestore: searching media for dump
xfsdump: ino map phase 1: constructing initial dump list
xfsdump: ino map phase 2: skipping (no pruning necessary)
xfsdump: ino map phase 3: skipping (only one dump stream)
xfsdump: ino map construction complete
xfsdump: estimated dump size: 3324047232 bytes
xfsdump: creating dump session media file 0 (media 0, file 0)
xfsdump: dumping ino map
xfsdump: dumping directories
xfsrestore: examining media file 0
xfsrestore: dump description: 
xfsrestore: hostname: lvm
xfsrestore: mount point: /
xfsrestore: volume: /dev/mapper/vg_root-lv_root
xfsrestore: session time: Mon Aug 14 12:07:58 2023
xfsrestore: level: 0
xfsrestore: session label: ""
xfsrestore: media label: ""
xfsrestore: file system id: dc702826-a1c3-4735-b4e8-7a4371a98054
xfsrestore: session id: bde4fe3b-c89a-4505-bb6d-7e7195fdaa78
xfsrestore: media id: 8ee5d10b-e29d-4a3e-88aa-108ab1167d08
xfsrestore: searching media for directory dump
xfsrestore: reading directories
xfsdump: dumping non-directory files
xfsrestore: 2962 directories and 31667 entries processed
xfsrestore: directory post-processing
xfsrestore: restoring non-directory files
xfsdump: ending media file
xfsdump: media file size 3287286176 bytes
xfsdump: dump size (non-dir files) : 3268910664 bytes
xfsdump: dump complete: 11 seconds elapsed
xfsdump: Dump Status: SUCCESS
xfsrestore: restore complete: 11 seconds elapsed
xfsrestore: Restore Status: SUCCESS


[root@lvm ~]# for i in /proc/ /sys/ /dev/ /run/ /boot/; do mount --bind $i /mnt/$i; done
[root@lvm ~]# chroot /mnt

### прописываем в /etc/grub/default конфигурацию для монтирования `/`
### ... GRUB_CMDLINE_LINUX="rd.lvm.lv=VolGroup00/LogVol00

sed -i 's/vg_root\/lv_root/VolGroup00\/LogVol00/g' /etc/default/grub


[root@lvm boot]# cd /boot ; for i in `ls initramfs-*img`; do dracut -v $i `echo $i|sed "s/initramfs-//;s/.img//g"` --force; done  

*** Including module: bash ***
*** Including module: nss-softokn ***
*** Including module: i18n ***
*** Including module: dm ***
Skipping udev rule: 64-device-mapper.rules
Skipping udev rule: 60-persistent-storage-dm.rules
Skipping udev rule: 55-dm.rules
*** Including module: kernel-modules ***
Omitting driver floppy
*** Including module: lvm ***
Skipping udev rule: 64-device-mapper.rules
Skipping udev rule: 56-lvm.rules
Skipping udev rule: 60-persistent-storage-lvm.rules
*** Including module: qemu ***
*** Including module: rootfs-block ***
*** Including module: terminfo ***
*** Including module: udev-rules ***
Skipping udev rule: 40-redhat-cpu-hotplug.rules
Skipping udev rule: 91-permissions.rules
*** Including module: biosdevname ***
*** Including module: systemd ***
*** Including module: usrmount ***
*** Including module: base ***
*** Including module: fs-lib ***
*** Including module: shutdown ***
*** Including modules done ***
*** Installing kernel module dependencies and firmware ***
*** Installing kernel module dependencies and firmware done ***
*** Resolving executable dependencies ***
*** Resolving executable dependencies done***
*** Hardlinking files ***
*** Hardlinking files done ***
*** Stripping files ***
*** Stripping files done ***
*** Generating early-microcode cpio image contents ***
*** No early-microcode cpio image needed ***
*** Store current command line parameters ***
*** Creating image file ***
*** Creating image file done ***
*** Creating initramfs image file '/boot/initramfs-3.10.0-1127.el7.x86_64.img' done ***


[root@lvm boot]# grub2-mkconfig -o /boot/grub2/grub.cfg
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-3.10.0-1127.el7.x86_64
Found initrd image: /boot/initramfs-3.10.0-1127.el7.x86_64.img
done
```

### 02 Выделение тома под `/var`
Том необходимо выделить с поддержкой зеркалирования


**Создание тома с поддержкой зеркалировния**
```bash
[root@lvm boot]# pvcreate /dev/sdc /dev/sdd
  Physical volume "/dev/sdc" successfully created.
  Physical volume "/dev/sdd" successfully created.
[root@lvm boot]# vgcreate vg_var /dev/sdc /dev/sdd
  Volume group "vg_var" successfully created
[root@lvm boot]# lvcreate -L 950M -m1 -n lv_var vg_var
  Rounding up size to full physical extent 952.00 MiB
  Logical volume "lv_var" created
[root@lvm boot]# mkfs.ext4 /dev/vg_var/lv_var
mke2fs 1.42.9 (28-Dec-2013)
Filesystem label=
OS type: Linux
Block size=4096 (log=2)
Fragment size=4096 (log=2)
Stride=0 blocks, Stripe width=0 blocks
60928 inodes, 243712 blocks
12185 blocks (5.00%) reserved for the super user
First data block=0
Maximum filesystem blocks=249561088
8 block groups
32768 blocks per group, 32768 fragments per group
7616 inodes per group
Superblock backups stored on blocks: 
	32768, 98304, 163840, 229376

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done

```

**Перемещаем файлы в новый том**
```bash
[root@lvm boot]# mount /dev/vg_var/lv_var /mnt
[root@lvm boot]# cp -aR /var/* /mnt
[root@lvm boot]# mkdir /tmp/oldvar && mv /var/* /tmp/oldvar
[root@lvm boot]# umount /mnt
[root@lvm boot]# mount /dev/vg_var/lv_var /var
[root@lvm boot]# blkid | grep var: | awk '{print $2}'
UUID="25a36fea-f6af-44aa-b9da-10d1568d76b7"
[root@lvm boot]# echo "`blkid | grep var: | awk '{print $2}'` /var ext4 defaults 0 0" >> /etc/fstab
```

### 03. Сделать поддержку снапшотов для `/home`

**Перемещаем содержимое `/home` в отдельный том**
```bash
[root@lvm boot]# lvcreate -n LogVol_Home -L 2G /dev/VolGroup00
  Logical volume "LogVol_Home" created.
[root@lvm boot]# mkfs.xfs /dev/VolGroup00/LogVol_Home 
meta-data=/dev/VolGroup00/LogVol_Home isize=512    agcount=4, agsize=131072 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=0, sparse=0
data     =                       bsize=4096   blocks=524288, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal log           bsize=4096   blocks=2560, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
[root@lvm boot]# mount /dev/VolGroup00/LogVol_Home /mnt
[root@lvm boot]# cp -aR /home/* /mnt
[root@lvm boot]# rm -rf /home/*
[root@lvm boot]# umount /mnt
[root@lvm boot]# mount /dev/VolGroup00/LogVol_Home /home/
[root@lvm boot]# echo "`blkid | grep Home: | awk '{print $2}'` /home xfs defaults 0 0" >> /etc/fstab
```

**Удаляем временный том**
```bash

[root@lvm ~]# lvremove /dev/vg_root/lv_root
Do you really want to remove active logical volume vg_root/lv_root? [y/n]: н
  WARNING: Invalid input ''.
Do you really want to remove active logical volume vg_root/lv_root? [y/n]: y
  Logical volume "lv_root" successfully removed
[root@lvm ~]# vgremove /dev/vg_root
  Volume group "vg_root" successfully removed
[root@lvm ~]# pvremove /dev/sdb
  Labels on physical volume "/dev/sdb" successfully wiped.

```

**Перезагружаемся и проверяем состояние системы**
```bash
[vagrant@lvm ~]$ lsblk
NAME                       MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                          8:0    0   40G  0 disk 
├─sda1                       8:1    0    1G  0 part /boot
└─sda2                       8:2    0   39G  0 part 
  ├─VolGroup00-LogVol00    253:0    0    8G  0 lvm  /
  └─VolGroup00-LogVol_Home 253:1    0    2G  0 lvm  /home
sdb                          8:16   0   10G  0 disk 
└─vg_root-lv_root          253:2    0   10G  0 lvm  
sdc                          8:32   0    2G  0 disk 
├─vg_var-lv_var_rmeta_0    253:3    0    4M  0 lvm  
│ └─vg_var-lv_var          253:7    0  952M  0 lvm  /var
└─vg_var-lv_var_rimage_0   253:4    0  952M  0 lvm  
  └─vg_var-lv_var          253:7    0  952M  0 lvm  /var
sdd                          8:48   0    1G  0 disk 
├─vg_var-lv_var_rmeta_1    253:5    0    4M  0 lvm  
│ └─vg_var-lv_var          253:7    0  952M  0 lvm  /var
└─vg_var-lv_var_rimage_1   253:6    0  952M  0 lvm  
  └─vg_var-lv_var          253:7    0  952M  0 lvm  /var
sde                          8:64   0    1G  0 disk 

```


### 04. Работа со снапшотами

```bash
[root@lvm ~]# touch /home/file{1..20}
[root@lvm ~]# lvcreate -L 100MB -s -n home_snap /dev/VolGroup00/LogVol_Home
  Logical volume "home_snap" created.
[root@lvm ~]# rm -f /home/file{11..20}
[root@lvm ~]# ls /home
file1  file10  file2  file3  file4  file5  file6  file7  file8  file9  vagrant
[root@lvm ~]# umount /home
[root@lvm ~]# lvconvert --merge /dev/VolGroup00/home_snap
  Merging of volume VolGroup00/home_snap started.
  VolGroup00/LogVol_Home: Merged: 100.00%
[root@lvm ~]# mount /home
[root@lvm ~]# ls /home
file1  file10  file11  file12  file13  file14  file15  file16  file17  file18  file19  file2  file20  file3  file4  file5  file6  file7  file8  file9  vagrant
```
