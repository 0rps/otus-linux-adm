# Работа с PAM

### Задание

1) Запретить всем пользователям, кроме группы admin, логин в выходные (суббота и воскресенье), без учета праздников

2) Дать конкретному пользователю права работать с докером и возможность рестартить докер сервис

### Немного о Vagrantfile

`Vagrantfile` основан на Ubuntu 23.04, поэтому там будет несколько нюансов.
В качестве конфигурационного скрипта используется [provisioner.sh](./provisioner.sh).

### Учет выходных при SSH логине
Для начала поправим строчку с `PasswordAuthentication` в файле `/etc/ssh/sshd_config.d/60-cloudimg-settings.conf`, т.к. по умолчанию `PasswordAuthentication` в нем выставлен в `no`.

```bash
sed -i 's/^PasswordAuthentication.*$/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
systemctl restart ssh.service
```

Далее добавим пользователей `otus` и `otusadm`. Добавим их в группу `admin`

```bash
useradd otusadm && useradd otus
echo -e 'Otus2023!\nOtus2023!' | passwd otusadm
echo -e 'Otus2023!\nOtus2023!' | passwd otus
groupadd -f admin
echo -n "otusadm;root;vagrant" | xargs -d ';' -I {} usermod {} -a -G admin
```

Добавим правило в PAM
```
sudo cp /vagrant/files/login.sh /usr/local/bin/login.sh
chmod +x /usr/local/bin/login.sh
echo "auth required pam_exec.so debug /usr/local/bin/login.sh" >> /etc/pam.d/sshd
```

Тело правило выглядит следующим образом и слегка отличается от методички:
```bash
#!/bin/bash
if getent group admin | grep -qw "$PAM_USER"; then
        exit 0
fi

if [ $(date +%a) = "Sat" ] || [ $(date +%a) = "Sun" ]; then
        exit 1
else
        exit 0
fi
```

Проверим, что пользователь `otus` не может логиниться через ssh в субботу: попробуем залогиниться и посмотрим логи.

```bash
#
>>> ssh otus@192.168.57.10 
...
#
root@pam:~# date
Sat Oct 28 03:10:39 PM UTC 2023

root@pam:~# cat /var/log/auth.log | tail -n 4  
Oct 28 15:10:23 ubuntu-jammy sshd[2775]: pam_exec(sshd:auth): Calling /usr/local/bin/login.sh ...
Oct 28 15:10:23 ubuntu-jammy sshd[2770]: pam_exec(sshd:auth): /usr/local/bin/login.sh failed: exit code 1
Oct 28 15:10:25 ubuntu-jammy sshd[2770]: Failed password for otus from 192.168.57.1 port 44986 ssh2
Oct 28 15:10:28 ubuntu-jammy sshd[2770]: Connection closed by authenticating user otus 192.168.57.1 port 44986 [preauth]
```

Как видим скрипт вернул код `1`.

### Дать определенному пользователю работать с докером и рестартовать его

Для того, чтобы дать пользователю работать с `docker`, его можно добавить в стандартную группу `docker`
```bash
usermod otus -a -G docker
#----
docker run hello-world
```

А для того, чтобы дать ему права, чтобы через `systemctl` рестартовать необходимо написать небольшое правило для `polkit`:
```js
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
```
В правиле выше есть команда, которая пишет определенную строчку в лог, чтобы можно было понять, что правило сработало.

Также необходимо убрать из `unit` файла для `polkit` параметр запуска `--no-debug`, что дать возможность писать логи в `journalctl`:

```bash
sudo sed 's/--no-debug//g' /usr/lib/systemd/system/polkit.service > /tmp/polkit.service
sudo cp -f /tmp/polkit.service /usr/lib/systemd/system/polkit.service
sudo systemctl daemon-reload
sudo systemctl restart polkit.service
```

И проверим, работает ли это правило:
```bash
systemctl restart docker.service
```

Сервис перезагрузится и появятся следующий лог в `journalctl`:
```bash
Oct 29 00:03:31 pam polkitd[3518]: Registered Authentication Agent for unix-process:3826:14282 (system bus name :1.42 [/usr/bin/pkttyagent --notify-fd 5 --fallback], object path /org/freedesktop/PolicyKit1/Authent
icationAgent, locale C.UTF-8)                                                                            
Oct 29 00:03:31 pam polkitd[3518]: 00:03:31.794: Registered Authentication Agent for unix-process:3826:14282 (system bus name :1.42 [/usr/bin/pkttyagent --notify-fd 5 --fallback], object path /org/freedesktop/Poli
cyKit1/AuthenticationAgent, locale C.UTF-8)                                                              
Oct 29 00:03:31 pam polkitd[3518]: Custom rule for 'otus' user to manage docker service is triggered     
Oct 29 00:03:31 pam systemd[1]: Stopping docker.service - Docker Application Container Engine... 
```

Как видим - появилась запись из нашего правила `Custom rule for 'otus' user to...`.

**NOTE**: маленькое замечание. Удивился тому, что в Ubuntu 22.04 используется по умолчанию достаточно старая версия polkit, где невозможно писать правила. Там можно было управлять только `localauthority` файлами, где был очень ограниченный функционал для настроек.