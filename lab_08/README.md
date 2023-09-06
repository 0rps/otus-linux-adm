# Работа с systemd

**Задание:** 
* Написать сервис, который будет мониторить лог файл на предмет наличия ключевого слова
* Установить `spawn-fcgi` и переписать `init` скрипт на `unit`-файл.
* Дополнить `unit`-файл сервиса `apache2` возможностью запуска нескольких экземпляров сервиса с разными конфигурациями

### 00. Vagrantfile

Лабораторная работа построена на основе Ubuntu, поэтому будут присутстовать некоторые отличие в процессе выполнения от методички, в особенности в последнем задании.

Основной блок `Vagrantfile` выглядит следующим образом:
```ruby
  config.vm.define "systemd" do |node| 
    node.vm.hostname = "systemd" 

    config.vm.provision "file", source: "./watchlog_service/", destination: "/tmp"
    config.vm.provision "file", source: "./fcgi_service/", destination: "/tmp/"
    config.vm.provision "file", source: "./apache2/", destination: "/tmp/"

    config.vm.provision "shell", path: "provision.sh"
  end
``` 

3 директории со файлами для каждого задания и один `provision` скрипт.
Из особенностей в работе скрипта:
```bash
groupadd apache
useradd -g apache -G www-data apache
```

Здесь добавляется пользователь `apache`, хотя можно было воспользоваться пользователем `www-data`. Данный пользователь будет использован только во втором задании.

В конце перезагружаем `systemd` и выключаем `apache2`
```bash
systemctl daemon-reload
systemctl disable apache2 
systemctl stop apache2 
```

Это нужно для того, чтобы выполнять все последующие действия в интерактивном режиме, а не автоматическом.

### 01. logwatch-timer

Конфигурационный файл для работы `logwatch` скрипта (`/etc/sysconfig/watchlog`)
```
WORD=ALERT
LOG=/var/log/watchlog.log
```

`watchlog` скрипт
```bash
#!/bin/bash

WORD=$1
LOG=$2
DATE=`date`

if grep $WORD $LOG &> /dev/null
then
  logger "$DATE: I found word, Master!"
else
  exit 0
fi
```

При копировании скрипта на `provision` стадии не забываем про `chmod +x /opt/watchlog.sh`.

`Unit` файл для `watchlog` сервиса (по пути `/etc/systemd/system/watchlog.service`) 
```ini
[Unit]
Description=My watchlog service

[Service]
Type=oneshot
EnvironmentFile=/etc/sysconfig/watchlog
ExecStart=/opt/watchlog.sh $WORD $LOG
```

А `unit` файл для `timer` сервиса выглядит так (`/etc/systemd/system/watchlog.timer`):
```ini
[Unit]
Description=Run watchlog script every 30 second

[Timer]
# Очень важная настройка, т.к. без нее не будет первого запуска сервиса 
OnActiveSec=1

# Данный параметр работает после первого запуска сервиса
OnUnitActiveSec=30
Unit=watchlog.service

[Install]
WantedBy=multi-user.target
```

Давайте проверим, как он работает:
```bash

# проверим статус таймера
root@systemd:/home/vagrant# systemctl status watchlog.timer
● watchlog.timer - Run watchlog script every 30 second
     Loaded: loaded (/etc/systemd/system/watchlog.timer; disabled; vendor preset: enabled)
     Active: active (waiting) since Wed 2023-09-06 20:46:32 UTC; 35s ago
    Trigger: Wed 2023-09-06 20:47:29 UTC; 21s left
   Triggers: ● watchlog.service

# статус сервиса
Sep 06 20:46:32 systemd systemd[1]: Started Run watchlog script every 30 second.
root@systemd:/home/vagrant# systemctl status watchlog.service
○ watchlog.service - My watchlog service
     Loaded: loaded (/etc/systemd/system/watchlog.service; static)
     Active: inactive (dead) since Wed 2023-09-06 20:46:59 UTC; 12s ago
TriggeredBy: ● watchlog.timer
    Process: 11669 ExecStart=/opt/watchlog.sh $WORD $LOG (code=exited, status=0/SUCCESS)
   Main PID: 11669 (code=exited, status=0/SUCCESS)
        CPU: 5ms

Sep 06 20:46:59 systemd systemd[1]: Starting My watchlog service...
Sep 06 20:46:59 systemd systemd[1]: watchlog.service: Deactivated successfully.
Sep 06 20:46:59 systemd systemd[1]: Finished My watchlog service.

# добавим ключевое слово в логи, которые анализируется watchlog
root@systemd:/home/vagrant# echo "ALERT" > /var/log/watchlog.log

# проверим логи и статус сервиса
root@systemd:/home/vagrant# systemctl status watchlog.service
○ watchlog.service - My watchlog service
     Loaded: loaded (/etc/systemd/system/watchlog.service; static)
     Active: inactive (dead) since Wed 2023-09-06 20:52:58 UTC; 8s ago
TriggeredBy: ● watchlog.timer
    Process: 11804 ExecStart=/opt/watchlog.sh $WORD $LOG (code=exited, status=0/SUCCESS)
   Main PID: 11804 (code=exited, status=0/SUCCESS)
        CPU: 6ms

Sep 06 20:52:58 systemd systemd[1]: Starting My watchlog service...
Sep 06 20:52:58 systemd root[11807]: Wed Sep  6 20:52:58 UTC 2023: I found word, Master!
Sep 06 20:52:58 systemd systemd[1]: watchlog.service: Deactivated successfully.
Sep 06 20:52:58 systemd systemd[1]: Finished My watchlog service.
```

### 02. `spawn-fcgi`

Установка пакетов в `provision` скрипте:
```bash
apt install -y tmux mc php php-cli apache2 libapache2-mod-fcgid spawn-fcgi php-cgi
```

Конфигурация для сервиса (`/etc/sysconfig/spawn-fcgi`)
```env
SOCKET=/var/run/php-fcgi.sock
OPTIONS="-u apache -g apache -s $SOCKET -S -M 0600 -C 32 -F 1 -- /usr/bin/php-cgi"
```
Как видим выше используются пользователь `apache:apache`, который был создан при инициализации машины.

`Unit` файл для сервиса
```ini
[Unit]
Description=Spawn-fcgi startup service by Otus
After=network.target

[Service]
Type=simple
PIDFile=/run/spawn-fcgi.pid
EnvironmentFile=/etc/sysconfig/spawn-fcgi
ExecStart=/usr/bin/spawn-fcgi -n $OPTIONS
KillMode=process

[Install]
WantedBy=multi-user.target
```

Проверим работу сервиса
```
root@systemd:/home/vagrant# systemctl start spawn-fcgi

root@systemd:/home/vagrant# systemctl status spawn-fcgi
● spawn-fcgi.service - Spawn-fcgi startup service by Otus
     Loaded: loaded (/etc/systemd/system/spawn-fcgi.service; disabled; vendor preset: enabled)
     Active: active (running) since Wed 2023-09-06 20:56:53 UTC; 8s ago
   Main PID: 11941 (php-cgi)
      Tasks: 33 (limit: 497)
     Memory: 19.2M
        CPU: 16ms
     CGroup: /system.slice/spawn-fcgi.service
             ├─11941 /usr/bin/php-cgi
             ├─11945 /usr/bin/php-cgi
             ├─11946 /usr/bin/php-cgi
             ├─11947 /usr/bin/php-cgi
             ├─11948 /usr/bin/php-cgi
             ├─11949 /usr/bin/php-cgi
             ├─11950 /usr/bin/php-cgi
             ├─11951 /usr/bin/php-cgi
             ├─11952 /usr/bin/php-cgi
             ├─11953 /usr/bin/php-cgi
             ├─11954 /usr/bin/php-cgi
             ├─11955 /usr/bin/php-cgi
             ├─11956 /usr/bin/php-cgi
             ├─11957 /usr/bin/php-cgi
             ├─11958 /usr/bin/php-cgi
             ├─11959 /usr/bin/php-cgi
             ├─11960 /usr/bin/php-cgi
             ├─11961 /usr/bin/php-cgi
             ├─11962 /usr/bin/php-cgi
             ├─11963 /usr/bin/php-cgi
             ├─11964 /usr/bin/php-cgi
             ├─11965 /usr/bin/php-cgi
             ├─11966 /usr/bin/php-cgi
             ├─11967 /usr/bin/php-cgi
             ├─11968 /usr/bin/php-cgi
             ├─11969 /usr/bin/php-cgi
             ├─11970 /usr/bin/php-cgi
             ├─11971 /usr/bin/php-cgi
             ├─11972 /usr/bin/php-cgi
             ├─11973 /usr/bin/php-cgi
             ├─11974 /usr/bin/php-cgi
             ├─11975 /usr/bin/php-cgi
             └─11976 /usr/bin/php-cgi

Sep 06 20:56:53 systemd systemd[1]: Started Spawn-fcgi startup service by Otus.
```

### 02. Запуск нескольких экземляров apache2

Данная часть отняла больше всего времени, т.к. пакеты в `centos` и `ubuntu` отличаются.
Для начала установим `apache2` (он уже был установлен для 2го задания).

Далее необходимо найти минимальную конфигурацию запуска `apache2`, путем экспериментов у меня она получилась следующая (`/etc/apache2/apache2.conf`):

```ini
User www-data
Group www-data
IncludeOptional mods/*.load

ErrorLog /var/log/apache2/error-first.log
PidFile /var/run/apache2-first.pid
Listen 81
```

Для разных экзепляров `apache` были созданы 2 папки:
* `/etc/apache2_custom/first`
* `/etc/apache2_custom/second`

В каждой из которых находился один файл конфигурации и один `mpm_prefork.load` модуль, без которого apache не работал.
Основная разница конфигураций экзепляров - номер порта, путь до логов и путь до `pid` файла.


Шаблон `unit` файла `apache2` сервиса выглядит так (`/usr/lib/systemd/system/apache2@.service`)
```ini
[Unit]
Description=The Apache HTTP Server
After=network.target remote-fs.target nss-lookup.target
Documentation=https://httpd.apache.org/docs/2.4/

[Service]
Type=forking

# configuration for apache config folder management
Environment=APACHE_CONFDIR=/etc/apache2-custom/%i APACHE_STARTED_BY_SYSTEMD=true

ExecStart=/usr/sbin/apachectl start
ExecStop=/usr/sbin/apachectl graceful-stop
ExecReload=/usr/sbin/apachectl graceful
KillMode=mixed
PrivateTmp=true
Restart=on-abort

[Install]
WantedBy=multi-user.target
```

Основной переменной, которая определяет путь до конфига является `APACHE_CONFDIR=/etc/apache2-custom/%i`.

После всех приготовлений давайте запустим два экзепляра `apache2` на портах 81 и 82 и проверим, что действительно эти порты оказались открыты.

```bash

root@systemd:/home/vagrant# systemctl start apache2@first
root@systemd:/home/vagrant# systemctl start apache2@second
root@systemd:/home/vagrant# ss -tnulp | grep apache
tcp   LISTEN 0      511                   *:81              *:*    users:(("apache2",pid=12071,fd=4),("apache2",pid=12070,fd=4),("apache2",pid=12069,fd=4),("apache2",pid=12068,fd=4),("apache2",pid=12067,fd=4),("apache2",pid=12066,fd=4))
tcp   LISTEN 0      511                   *:82              *:*    users:(("apache2",pid=12083,fd=4),("apache2",pid=12082,fd=4),("apache2",pid=12081,fd=4),("apache2",pid=12080,fd=4),("apache2",pid=12079,fd=4),("apache2",pid=12078,fd=4))
```

Как и ожидалось, порты 81 и 82 открыты.
