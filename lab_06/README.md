## Управление пакетами и дистрибьюция софта

**Цель:** научиться работать с менеджером пакетов

В качестве исходников RPM пакета был выбран маленький go-based http сервер, который стартует на порту 7080 и умеет отдавать страничку с `200 OK`` статусом.

При выполнении данного задания были созданы следующие provision файлы/папки/скрипты:
* `files/webgostatus-1.0` - исходные файлы сервера
* `files/webgostatus.spec` - конфигурация сборки RPM пакета
* `files/nginx.conf` - модифицированная конфигурация NGINX с добавленной инструкцией `autoindex`
* `00-rpm-build.sh` - скрипт, который производит сборку RPM пакета

### Создание RPM пакета

#### 1. Установка необходимых пакетов для сборки RPM пакета

```bash
yum install -y \
  rpmdevtools \
  rpm-build \
  golang \
  make \
  yum-utils 
```

#### 2. Генерируем структуру под сборку RPM пакета, копируем исходники и конфигурацию сборку. Собираем
```bash
rpmdev-setuptree
cp ~/tmp/webgostatus.spec ~/rpmbuils/SPECS
tar cvfz ~/rpmbuild/SOURCES/webgostatus-1.0.tar.gz  ~/tmp/webgostatus-1.0
rpmbuild -bb ~/rpmbuild/SPECS/webgostatus.spec
```

#### 3. Проверяем, что пакет собрался

```bash
ls ~/rpmbuild/RPMS/x86_64/
>>> rpm-repo: webgostatus-1.0-1.el9.x86_64.rpm
```

### Публикация пакета на собственном REPO

#### 1. Устанавливаем nginx и reposerver
```bash
yum install -y createrepo nginx
```

#### 2. Создаем директории, копируем пакет, генерируем метадату REPO

```bash
mkdir /usr/share/nginx/html/repo
cp ~/rpmbuild/RPMS/x86_64/* /usr/share/nginx/html/repo/
createrepo /usr/share/nginx/html/repo/

    rpm-repo: Directory walk started
    rpm-repo: Directory walk done - 1 packages
    rpm-repo: Temporary output repo path: /usr/share/nginx/html/repo/.repodata/
    rpm-repo: Preparing sqlite DBs            
    rpm-repo: Pool started (with 5 workers)
    rpm-repo: Pool finished       
```

#### 3. Копируем измененный конфиг nginx, запускаем сервер и проверяем

```bash
cp -f /tmp/files/nginx.conf /etc/nginx/nginx.conf
nginx -t
systemctl start nginx
curl -a http://localhost/repo/

    rpm-repo: <html>                                                                                      
    rpm-repo: <head><title>Index of /repo/</title></head>                                                 
    rpm-repo: <body>                                                                                                                                                                                                 
    rpm-repo: <h1>Index of /repo/</h1><hr><pre><a href="../">../</a>                                                                                                                                                 
    rpm-repo: <a href="repodata/">repodata/</a>                                          04-Aug-2023 16:52                   -                                                                                       
    rpm-repo: <a href="webgostatus-1.0-1.el9.x86_64.rpm">webgostatus-1.0-1.el9.x86_64.rpm</a>                   04-Aug-2023 16:52             1858264
    rpm-repo: </pre><hr></body>                                                                                                                                                                                      
    rpm-repo: </html>  
```

#### 4. Добавляем новый репозиторий в yum

```bash
cat >> /etc/yum.repos.d/otus.repo << EOF
[otus]
name=otus-linux
baseurl=http://localhost/repo
gpgcheck=0
enabled=1
EOF

yum repolist enabled | grep otus
yum list | grep otus

    rpm-repo: otus                otus-linux                                                                   
    rpm-repo: otus-linux              197 kB/s | 1.0 kB     00:00    
    rpm-repo: webgostatus.x86_64      el9                     otus
```

#### 5. Устанавливаем сервер из нашего RPM пакета и запускаем для проверки
```bash
yum install -y webgostatus
webgostatus &
sleep 1
curl http://localhost:7080


    rpm-repo: got / request
    rpm-repo: Status: OK
```
