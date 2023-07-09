# LAB 01: С чего начинается Linux

## Задание 1: Обновить ядро ОС из репозитория ELRepo

### Vagrantfile
```Vagrantfile
MACHINES = {
  :"kernel-update" => {
              :box_name => "centos/8",
              :box_version => "2011.0",
              :cpus => 2,
              :memory => 1024,
            }
}

Vagrant.configure("2") do |config|
  MACHINES.each do |boxname, boxconfig|
    # Отключаем проброс общей папки в ВМ
    config.vm.synced_folder ".", "/vagrant", disabled: true
    # Применяем конфигурацию ВМ
    config.vm.define boxname do |box|
      box.vm.box = boxconfig[:box_name]
      box.vm.box_version = boxconfig[:box_version]
      box.vm.host_name = boxname.to_s
      box.vm.provider "virtualbox" do |v|
        v.memory = boxconfig[:memory]
        v.cpus = boxconfig[:cpus]
      end
    end
  end
end
```


### Запуск виртуальной машины и ssh доступ
```
➜ vagrant up                             
Bringing machine 'kernel-update' up with 'virtualbox' provider...
==> kernel-update: Box 'centos/8' could not be found. Attempting to find and install...                  
    kernel-update: Box Provider: virtualbox 
    kernel-update: Box Version: 2011.0                                                                   
==> kernel-update: Loading metadata for box 'centos/8'                                                   
    kernel-update: URL: https://vagrantcloud.com/centos/8                                                
==> kernel-update: Adding box 'centos/8' (v2011.0) for provider: virtualbox            
    kernel-update: Downloading: https://vagrantcloud.com/centos/boxes/8/versions/2011.0/providers/virtualbox.box
Download redirected to host: cloud.centos.org
    kernel-update: Calculating and comparing box checksum...
==> kernel-update: Successfully added box 'centos/8' (v2011.0) for 'virtualbox'!
==> kernel-update: Importing base box 'centos/8'...                                                      
==> kernel-update: Matching MAC address for NAT networking...                                            
==> kernel-update: Checking if box 'centos/8' version '2011.0' is up to date...
==> kernel-update: Setting the name of the VM: linux_adm_kernel-update_1688581445307_17593
==> kernel-update: Clearing any previously set network interfaces...
==> kernel-update: Preparing network interfaces based on configuration...       
    kernel-update: Adapter 1: nat                  
==> kernel-update: Forwarding ports...                                                                   
    kernel-update: 22 (guest) => 2222 (host) (adapter 1)                       
==> kernel-update: Running 'pre-boot' VM customizations...                                
==> kernel-update: Booting VM...                                                                         
==> kernel-update: Waiting for machine to boot. This may take a few minutes...
    kernel-update: SSH address: 127.0.0.1:2222
    kernel-update: SSH username: vagrant
    kernel-update: SSH auth method: private key                                                          
    kernel-update:                                                                                       
    kernel-update: Vagrant insecure key detected. Vagrant will automatically replace
    kernel-update: this with a newly generated keypair for better security.   
    kernel-update:                                  
    kernel-update: Inserting generated public key within guest...
    kernel-update: Removing insecure key from the guest if it's present...
    kernel-update: Key inserted! Disconnecting and reconnecting using new SSH key...
==> kernel-update: Machine booted and ready!                                                             
==> kernel-update: Checking for guest additions in VM...                   
    kernel-update: No guest additions were detected on the base box for this VM! Guest
    kernel-update: additions are required for forwarded ports, shared folders, host only
    kernel-update: networking, and more. If SSH fails on this machine, please install
    kernel-update: the guest additions and repackage the box to continue.           
    kernel-update:                                  
    kernel-update: This is not an error message; everything may continue to work properly,
    kernel-update: in which case you may ignore this message.                         
==> kernel-update: Setting hostname...


➜ vagrant ssh
```


**Исправление ошибки с адресами репозиториев**

Ошибка связана с тем, что используется Centos 8, которая уже outdated, поэтому необходимо сменить URL репозиториев.

```
sudo sed -i -e "s|mirrorlist=|#mirrorlist=|g" /etc/yum.repos.d/CentOS-*
sudo sed -i -e "s|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g" /etc/yum.repos.d/CentOS-*
```

**Добавление elrepo**

```
sudo yum install -y https://www.elrepo.org/elrepo-release-8.el8.elrepo.noarch.rpm 
...
Running transaction
  Preparing        :                                                                                                                                                                                           1/1 
  Installing       : elrepo-release-8.3-1.el8.elrepo.noarch                                                                                                                                                    1/1 
  Verifying        : elrepo-release-8.3-1.el8.elrepo.noarch                                                                                                                                                    1/1 

Installed:
  elrepo-release-8.3-1.el8.elrepo.noarch                                                                                                                                                                           

Complete!
```

**Установка нового ядра**

```
sudo yum --enablerepo elrepo-kernel install kernel-ml -y

...
Running transaction
  Preparing        : 1/1 
  Installing       : kernel-ml-core-6.4.1-1.el8.elrepo.x86_64 1/3 
  Running scriptlet: kernel-ml-core-6.4.1-1.el8.elrepo.x86_64 1/3 
  Installing       : kernel-ml-modules-6.4.1-1.el8.elrepo.x86_64 2/3 
  Running scriptlet: kernel-ml-modules-6.4.1-1.el8.elrepo.x86_64 2/3 
  Installing       : kernel-ml-6.4.1-1.el8.elrepo.x86_64 3/3 
  Running scriptlet: kernel-ml-core-6.4.1-1.el8.elrepo.x86_64 3/3 
  Running scriptlet: kernel-ml-6.4.1-1.el8.elrepo.x86_64  3/3 
  Verifying        : kernel-ml-6.4.1-1.el8.elrepo.x86_64 1/3 
  Verifying        : kernel-ml-core-6.4.1-1.el8.elrepo.x86_64 2/3 
  Verifying        : kernel-ml-modules-6.4.1-1.el8.elrepo.x86_64 3/3 

Installed:
  kernel-ml-6.4.1-1.el8.elrepo.x86_64                              
  kernel-ml-core-6.4.1-1.el8.elrepo.x86_64                              
  kernel-ml-modules-6.4.1-1.el8.elrepo.x86_64                             

Complete!

```

**Обновление grub config**
```
sudo grub2-mkconfig -o /boot/grub2/grub.cfg

Generating grub configuration file ...
done


sudo grub2-set-default 0
```

**Проверка версии ядра до перезапуска**
```
uname -r                                                                      
4.18.0-240.1.1.el8_3.x86_64
```

**Проверка версии ядра после перезапуска**
```
uname -r
6.4.1-1.el8.elrepo.x86_64
```

## Задание 2: Создать Vagrant box c помощью Packer

**Запуск `packer build`**
```
➜  packer git:(lab_01) ✗ packer build centos.json
virtualbox-iso.centos-9: output will be in this color.

==> virtualbox-iso.centos-9: Cannot find "Default Guest Additions ISO" in vboxmanage output (or it is empty)
==> virtualbox-iso.centos-9: Retrieving Guest additions checksums
==> virtualbox-iso.centos-9: Trying https://download.virtualbox.org/virtualbox/6.1.38/SHA256SUMS
==> virtualbox-iso.centos-9: Trying https://download.virtualbox.org/virtualbox/6.1.38/SHA256SUMS
==> virtualbox-iso.centos-9: https://download.virtualbox.org/virtualbox/6.1.38/SHA256SUMS => /home/.../.cache/packer/b42da22ac8597efda6f360794462a703ebb6bc40
==> virtualbox-iso.centos-9: Retrieving Guest additions
==> virtualbox-iso.centos-9: Trying https://download.virtualbox.org/virtualbox/6.1.38/VBoxGuestAdditions_6.1.38.iso
==> virtualbox-iso.centos-9: Trying https://download.virtualbox.org/virtualbox/6.1.38/VBoxGuestAdditions_6.1.38.iso?checksum=54e62a292bd0178d352d395bb715fd8cd25927cc955ef052d69d4b42f2587165
==> virtualbox-iso.centos-9: https://download.virtualbox.org/virtualbox/6.1.38/VBoxGuestAdditions_6.1.38.iso?checksum=54e62a292bd0178d352d395bb715fd8cd25927cc955ef052d69d4b42f2587165 => /home/.../.cache/packer/35137738b958fb84fca1ab12aa5e675ff307ec60.iso
==> virtualbox-iso.centos-9: Retrieving ISO
==> virtualbox-iso.centos-9: Trying https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/iso/CentOS-Stream-9-20230704.1-x86_64-boot.iso
==> virtualbox-iso.centos-9: Trying https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/iso/CentOS-Stream-9-20230704.1-x86_64-boot.iso?checksum=md5%3Abad225d7f8e9222b8a01361649608da8
==> virtualbox-iso.centos-9: https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/iso/CentOS-Stream-9-20230704.1-x86_64-boot.iso?checksum=md5%3Abad225d7f8e9222b8a01361649608da8 => /home/.../.cache/packer/baee6f5767784442840b698c0758b8871bac9569.iso
==> virtualbox-iso.centos-9: Starting HTTP server on port 8406
==> virtualbox-iso.centos-9: Creating virtual machine...
==> virtualbox-iso.centos-9: Creating hard drive builds/packer-centos-vm.vdi with size 10240 MiB...
==> virtualbox-iso.centos-9: Mounting ISOs...
    virtualbox-iso.centos-9: Mounting boot ISO...
==> virtualbox-iso.centos-9: Creating forwarded port mapping for communicator (SSH, WinRM, etc) (host port 2435)
==> virtualbox-iso.centos-9: Executing custom VBoxManage commands...
    virtualbox-iso.centos-9: Executing: modifyvm packer-centos-vm --memory 1024
    virtualbox-iso.centos-9: Executing: modifyvm packer-centos-vm --cpus 2
==> virtualbox-iso.centos-9: Starting the virtual machine...
==> virtualbox-iso.centos-9: Waiting 10s for boot...
==> virtualbox-iso.centos-9: Typing the boot command...
==> virtualbox-iso.centos-9: Using SSH communicator to connect: 127.0.0.1
==> virtualbox-iso.centos-9: Waiting for SSH to become available...
==> virtualbox-iso.centos-9: Connected to SSH!
==> virtualbox-iso.centos-9: Uploading VirtualBox version info (6.1.38)
==> virtualbox-iso.centos-9: Uploading VirtualBox guest additions ISO...
==> virtualbox-iso.centos-9: Pausing 20s before the next provisioner...
==> virtualbox-iso.centos-9: Provisioning with shell script: scripts/stage-1-kernel-update.sh
==> virtualbox-iso.centos-9:
==> virtualbox-iso.centos-9: We trust you have received the usual lecture from the local System
==> virtualbox-iso.centos-9: Administrator. It usually boils down to these three things:
==> virtualbox-iso.centos-9:
==> virtualbox-iso.centos-9:     #1) Respect the privacy of others.
==> virtualbox-iso.centos-9:     #2) Think before you type.
==> virtualbox-iso.centos-9:     #3) With great power comes great responsibility.
==> virtualbox-iso.centos-9:
    virtualbox-iso.centos-9: CentOS Stream 9 - BaseOS                        2.9 MB/s | 6.5 MB     00:02
    virtualbox-iso.centos-9: CentOS Stream 9 - AppStream                     5.4 MB/s |  17 MB     00:03
    virtualbox-iso.centos-9: CentOS Stream 9 - Extras packages                10 kB/s |  12 kB     00:01
    virtualbox-iso.centos-9: elrepo-release-9.el9.elrepo.noarch.rpm          9.2 kB/s |  12 kB     00:01
    virtualbox-iso.centos-9: Dependencies resolved.
    virtualbox-iso.centos-9: ================================================================================
    virtualbox-iso.centos-9:  Package             Arch        Version                Repository         Size
    virtualbox-iso.centos-9: ================================================================================
    virtualbox-iso.centos-9: Installing:
    virtualbox-iso.centos-9:  elrepo-release      noarch      9.1-1.el9.elrepo       @commandline       12 k
    virtualbox-iso.centos-9:
    virtualbox-iso.centos-9: Transaction Summary
    virtualbox-iso.centos-9: ================================================================================
    virtualbox-iso.centos-9: Install  1 Package
    virtualbox-iso.centos-9:
    virtualbox-iso.centos-9: Total size: 12 k
    virtualbox-iso.centos-9: Installed size: 5.0 k
    virtualbox-iso.centos-9: Downloading Packages:
    virtualbox-iso.centos-9: Running transaction check
    virtualbox-iso.centos-9: Transaction check succeeded.
    virtualbox-iso.centos-9: Running transaction test
    virtualbox-iso.centos-9: Transaction test succeeded.
    virtualbox-iso.centos-9: Running transaction
    virtualbox-iso.centos-9:   Preparing        :                                                        1/1
    virtualbox-iso.centos-9:   Installing       : elrepo-release-9.1-1.el9.elrepo.noarch                 1/1
    virtualbox-iso.centos-9:   Verifying        : elrepo-release-9.1-1.el9.elrepo.noarch                 1/1
    virtualbox-iso.centos-9:
    virtualbox-iso.centos-9: Installed:
    virtualbox-iso.centos-9:   elrepo-release-9.1-1.el9.elrepo.noarch
    virtualbox-iso.centos-9:
    virtualbox-iso.centos-9: Complete!
    virtualbox-iso.centos-9: ELRepo.org Community Enterprise Linux Repositor 174 kB/s | 179 kB     00:01
    virtualbox-iso.centos-9: ELRepo.org Community Enterprise Linux Kernel Re 2.3 MB/s | 3.0 MB     00:01
    virtualbox-iso.centos-9: Dependencies resolved.
    virtualbox-iso.centos-9: ================================================================================
    virtualbox-iso.centos-9:  Package              Arch      Version                  Repository        Size
    virtualbox-iso.centos-9: ================================================================================
    virtualbox-iso.centos-9: Installing:
    virtualbox-iso.centos-9:  kernel-ml            x86_64    6.4.2-1.el9.elrepo       elrepo-kernel     37 k
    virtualbox-iso.centos-9: Installing dependencies:
    virtualbox-iso.centos-9:  kernel-ml-core       x86_64    6.4.2-1.el9.elrepo       elrepo-kernel     57 M
    virtualbox-iso.centos-9:  kernel-ml-modules    x86_64    6.4.2-1.el9.elrepo       elrepo-kernel     54 M
    virtualbox-iso.centos-9:
    virtualbox-iso.centos-9: Transaction Summary
    virtualbox-iso.centos-9: ================================================================================
    virtualbox-iso.centos-9: Install  3 Packages
    virtualbox-iso.centos-9:
    virtualbox-iso.centos-9: Total download size: 110 M
    virtualbox-iso.centos-9: Installed size: 155 M
    virtualbox-iso.centos-9: Downloading Packages:
    virtualbox-iso.centos-9: (1/3): kernel-ml-6.4.2-1.el9.elrepo.x86_64.rpm  132 kB/s |  37 kB     00:00
    virtualbox-iso.centos-9: (2/3): kernel-ml-modules-6.4.2-1.el9.elrepo.x86 3.9 MB/s |  54 MB     00:13
    virtualbox-iso.centos-9: (3/3): kernel-ml-core-6.4.2-1.el9.elrepo.x86_64 3.4 MB/s |  57 MB     00:16
    virtualbox-iso.centos-9: --------------------------------------------------------------------------------
    virtualbox-iso.centos-9: Total                                           6.5 MB/s | 110 MB     00:17
    virtualbox-iso.centos-9: ELRepo.org Community Enterprise Linux Kernel Re 1.6 MB/s | 1.7 kB     00:00
==> virtualbox-iso.centos-9: [sudo] password for vagrant: Importing GPG key 0xBAADAE52:
==> virtualbox-iso.centos-9:  Userid     : "elrepo.org (RPM Signing Key for elrepo.org) <secure@elrepo.org>"
==> virtualbox-iso.centos-9:  Fingerprint: 96C0 104F 6315 4731 1E0B B1AE 309B C305 BAAD AE52
==> virtualbox-iso.centos-9:  From       : /etc/pki/rpm-gpg/RPM-GPG-KEY-elrepo.org
    virtualbox-iso.centos-9: Key imported successfully
    virtualbox-iso.centos-9: Running transaction check
    virtualbox-iso.centos-9: Transaction check succeeded.
    virtualbox-iso.centos-9: Running transaction test
    virtualbox-iso.centos-9: Transaction test succeeded.
    virtualbox-iso.centos-9: Running transaction
    virtualbox-iso.centos-9:   Preparing        :                                                        1/1
    virtualbox-iso.centos-9:   Installing       : kernel-ml-core-6.4.2-1.el9.elrepo.x86_64               1/3
    virtualbox-iso.centos-9:   Running scriptlet: kernel-ml-core-6.4.2-1.el9.elrepo.x86_64               1/3
    virtualbox-iso.centos-9:   Installing       : kernel-ml-modules-6.4.2-1.el9.elrepo.x86_64            2/3
    virtualbox-iso.centos-9:   Running scriptlet: kernel-ml-modules-6.4.2-1.el9.elrepo.x86_64            2/3
    virtualbox-iso.centos-9:   Installing       : kernel-ml-6.4.2-1.el9.elrepo.x86_64                    3/3
    virtualbox-iso.centos-9:   Running scriptlet: kernel-ml-core-6.4.2-1.el9.elrepo.x86_64               3/3
    virtualbox-iso.centos-9:   Running scriptlet: kernel-ml-6.4.2-1.el9.elrepo.x86_64                    3/3
    virtualbox-iso.centos-9:   Verifying        : kernel-ml-6.4.2-1.el9.elrepo.x86_64                    1/3
    virtualbox-iso.centos-9:   Verifying        : kernel-ml-core-6.4.2-1.el9.elrepo.x86_64               2/3
    virtualbox-iso.centos-9:   Verifying        : kernel-ml-modules-6.4.2-1.el9.elrepo.x86_64            3/3
    virtualbox-iso.centos-9:
    virtualbox-iso.centos-9: Installed:
    virtualbox-iso.centos-9:   kernel-ml-6.4.2-1.el9.elrepo.x86_64
    virtualbox-iso.centos-9:   kernel-ml-core-6.4.2-1.el9.elrepo.x86_64
    virtualbox-iso.centos-9:   kernel-ml-modules-6.4.2-1.el9.elrepo.x86_64
    virtualbox-iso.centos-9:
    virtualbox-iso.centos-9: Complete!
==> virtualbox-iso.centos-9: Generating grub configuration file ...
==> virtualbox-iso.centos-9: Adding boot menu entry for UEFI Firmware Settings ...
==> virtualbox-iso.centos-9: done
    virtualbox-iso.centos-9: Grub update done.
==> virtualbox-iso.centos-9: Provisioning with shell script: scripts/stage-2-clean.sh
    virtualbox-iso.centos-9: Last metadata expiration check: 0:01:43 ago on Sun 09 Jul 2023 02:09:35 PM EDT.
    virtualbox-iso.centos-9: Dependencies resolved.
    virtualbox-iso.centos-9: Nothing to do.
    virtualbox-iso.centos-9: Complete!
    virtualbox-iso.centos-9: 33 files removed
==> virtualbox-iso.centos-9: [sudo] password for vagrant:
==> virtualbox-iso.centos-9: Gracefully halting virtual machine...
==> virtualbox-iso.centos-9: [sudo] password for vagrant:
==> virtualbox-iso.centos-9: Preparing to export machine...
    virtualbox-iso.centos-9: Deleting forwarded port mapping for the communicator (SSH, WinRM, etc) (host port 2435)
==> virtualbox-iso.centos-9: Exporting virtual machine...
    virtualbox-iso.centos-9: Executing: export packer-centos-vm --output builds/packer-centos-vm.ovf --manifest --vsys 0 --description CentOS Stream 9 with kernel 6.x --version 9
==> virtualbox-iso.centos-9: Cleaning up floppy disk...
==> virtualbox-iso.centos-9: Deregistering and deleting VM...
==> virtualbox-iso.centos-9: Running post-processor: vagrant
==> virtualbox-iso.centos-9 (vagrant): Creating a dummy Vagrant box to ensure the host system can create one correctly
==> virtualbox-iso.centos-9 (vagrant): Creating Vagrant box for 'virtualbox' provider
    virtualbox-iso.centos-9 (vagrant): Copying from artifact: builds/packer-centos-vm-disk001.vmdk
    virtualbox-iso.centos-9 (vagrant): Copying from artifact: builds/packer-centos-vm.mf
    virtualbox-iso.centos-9 (vagrant): Copying from artifact: builds/packer-centos-vm.ovf
    virtualbox-iso.centos-9 (vagrant): Renaming the OVF to box.ovf...
    virtualbox-iso.centos-9 (vagrant): Compressing: Vagrantfile
    virtualbox-iso.centos-9 (vagrant): Compressing: box.ovf
    virtualbox-iso.centos-9 (vagrant): Compressing: metadata.json
    virtualbox-iso.centos-9 (vagrant): Compressing: packer-centos-vm-disk001.vmdk
    virtualbox-iso.centos-9 (vagrant): Compressing: packer-centos-vm.mf
Build 'virtualbox-iso.centos-9' finished after 11 minutes 13 seconds.

==> Wait completed after 11 minutes 13 seconds

==> Builds finished. The artifacts of successful builds are:
--> virtualbox-iso.centos-9: 'virtualbox' provider box: centos-9-kernel-6-x86_64-Minimal.box
```

В результате из базового образа centos 9 stream была установлена система, установлено новое ядро из elrepo и выполнена очистка лишних файлов.

**Добавление образа в vagrant реестр, запуск и проверка версии ядра**

```

➜  packer git:(lab_01) ✗ vagrant box add centos9-kernel6 centos-9-kernel-6-x86_64-Minimal.box
==> box: Box file was not detected as metadata. Adding it directly...
==> box: Adding box 'centos9-kernel6' (v0) for provider: 
    box: Unpacking necessary files from: file:///home/.../Documents/otus-linux-adm/packer/centos-9-kernel-6-x86_64-Minimal.box
==> box: Successfully added box 'centos9-kernel6' (v0) for 'virtualbox'!


➜  git:(lab_01) ✗ vagrant init centos9-kernel6
➜  git:(lab_01) ✗ vagrant up
➜  git:(lab_01) ✗ vagrant ssh
[vagrant@otus-c8 ~]$ uname -r
6.4.2-1.el9.elrepo.x86_64

➜  git:(lab_01) ✗ vagrant destroy --force 
```

## Задание 3: Загрузить Vagrant box в Vagrant Cloud

После регистрации и получения токена на https://app.vagrantup.com/ выполняем

**Аутентификация на vagrant cloud**

```
➜  packer git:(lab_01) ✗ vagrant cloud auth login -u mogilnikoffalexey -t "$TOKEN"
The token was successfully saved.
You are already logged in.
```

**Загрузка образа**
```
➜  packer git:(lab_01) ✗ vagrant cloud publish --release mogilnikoffalexey/centos9-kernel6 1.0 virtualbox centos-9-kernel-6-x86_64-Minimal.box
You are about to publish a box on Vagrant Cloud with the following options:
mogilnikoffalexey/centos9-kernel6:   (v1.0) for provider 'virtualbox'
Automatic Release:     true
Do you wish to continue? [y/N]y
Saving box information...
Uploading provider with file /home/.../Documents/otus-linux-adm/packer/centos-9-kernel-6-x86_64-Minimal.box
```


## Замечания:

Во первом и втором задании используются разные базовые версии centos: centos 8 и centos 9 stream. 
Это связано с тем, что centos 9 stream нет на офицальном аккаунте https://app.vagrantup.com/centos, а с помощью packer уже можно было создать на основе образа актуальной версии дистрибутива.
