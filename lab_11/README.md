# Первые шаги с Ansible

**Задание:** 
Подготовить стенд на Vagrant как минимум с одним сервером. На этом сервере используя Ansible необходимо развернуть nginx со следующими условиями:

* необходимо использовать модуль yum/apt;
* конфигурационные файлы должны быть взяты из шаблона jinja2 с перемененными;
* после установки nginx должен быть в режиме enabled в systemd;
* должен быть использован notify для старта nginx после установки;
* сайт должен слушать на нестандартном порту - 8080, для этого использовать переменные в Ansible.

### Краткое описание выполнения задания

Выполнение задание разбито на два крупных блока:
* Подготовка vagrant конфигурации (т.к. хотелось бы не устанавливать ansible на локальную машину, а создать две виртуальные машины (control plane и worker))
* Написание ansible роли
* Проверка работы

## 01. Vagrant конфигурация

### Vagrant file

Vagrant file выглядит следующим образом
```ruby
WORKER_NODES = {
  worker: {
    ip: "192.168.56.11",
  },
}


Vagrant.configure(2) do |config| 
  config.vm.box = "ubuntu/jammy64" 
  config.vm.provider "virtualbox" do |v| 
      v.memory = 512 
      v.cpus = 1
  end 

  WORKER_NODES.each do |node_name, node_data|
    config.vm.define node_name do |node| 
      node.vm.network "private_network", ip: node_data[:ip],  virtualbox__intnet: "net1" 
      node.vm.hostname = node_name
      node.vm.provision "shell", path: "provisioner-worker-node.sh"
    end
  end

  config.vm.define "control" do |node| 
    node.vm.network "private_network", ip: "192.168.56.10",  virtualbox__intnet: "net1" 
    node.vm.hostname = "control" 

    config.vm.provision "file", source: "./files/ansible", destination: "/tmp/keys/ansible"
    config.vm.provision "file", source: "./files/ansible.pub", destination: "/tmp/keys/ansible.pub"
    config.vm.provision "file", source: "./playbooks", destination: "/tmp/playbooks"

    node.vm.provision "shell" do |s|
      # pass the ips of the worker nodes to the script
      ips =  WORKER_NODES.map { |k, v| v[:ip] }
      s.path = "provisioner-control-node.sh"
      s.args = ips
    end
  end
end 
```

В конфигурации выше нужно обратить внимание, что конфигурируются 2 виртуальные машины.
Машина с `ansible` и рабочая `node`.

**Файлы:**
* Заранее были сгенерированы ssh ключи доступа (`files/ansible.*`);
* В директории `./playbooks` будут лежать файлы ansible роли;
* Для каждого типа машины используются соответствующие скрипты инициализации.

### Control plane provisioning script

Данный скрипт имеет несколько секций.

Данная секция устанавливает необходимый `ansible` пакет и конфигурирует ключи `ssh`
```bash
# install all python modules
apt-get update
apt-get install -y ansible 

# setup SSH access for ansible
mkdir -p /home/vagrant/.ssh/
cp /tmp/keys/ansible "$PRIVATE_KEY_PATH"
cp /tmp/keys/ansible.pub "$PRIVATE_KEY_PATH.pub"

chmod 644 "$PRIVATE_KEY_PATH.pub"
chmod 600 "$PRIVATE_KEY_PATH"
```

Следующая секция копирует `ansible playbook` 
```bash
# create ansible directory and staging directory with hosts
mkdir -p "$ANSIBLE_ROOT/staging"

cp -r /tmp/playbooks/* "$ANSIBLE_ROOT"
```

Вся конфигурация была написана таким образом, что `worker` машин может быть несколько. 
Данная секция генерирует скрипт для добавления `worker` хостов в `known_hosts`, а также генерирует `inventory` файл для `ansible`. Все `worker` хосты именуются как `nginx_<index>`.

```bash
# create inventory file and script for adding fingerprints
index=0
for ip in $*; do
    echo "nginx_$index ansible_host=$ip ansible_port=22 ansible_user=vagrant ansible_ssh_private_key_file=$PRIVATE_KEY_PATH" >> "$ANSIBLE_ROOT/staging/hosts"
    ((index++))

    echo "ssh-keyscan -H $ip" >> "$ANSIBLE_ROOT/add_fingerprints.sh"
done
```

В последней секции генерируется `ansible.cfg` и выставляется настоящий владелец всех файлов, т.к. скрипт работает под `root`.
```bash
# create ansible.cfg
tee -a "$ANSIBLE_ROOT/ansible.cfg" <<EOF
[defaults]
inventory = staging/hosts
remote_user = vagrant
host_key_checking = False
retry_files_enabled = False
EOF

chown -R vagrant:vagrant /home/vagrant
```

### Worker node provisioning script

Данный скрипт выполняет только одну роль - добавляет `public key` для `control plane` машины в `authorized_keys` для ssh доступа.


## 02. Написание ansible role

### Создание ansible role

Было решено написать ansible роль, после запуска `ansible-galaxy role init nginx` получилась следующая конфигурация:
```bash
vagrant@control:~/ansible/roles$ tree ./nginx/
./nginx/
├── README.md
├── defaults
│   └── main.yml
├── handlers
│   └── main.yml
├── meta
│   └── main.yml
├── tasks
│   └── main.yml
├── tests
└── vars
    └── main.yml
```

Начнем с конца.

Добавим 2 handler'а для рестарта и релоада `nginx` в `handlers/main.yml`
```yml
---
- name: restart_nginx
  systemd:
    name: nginx
    state: restarted
    enabled: yes
- name: reload_nginx
  systemd:
    name: nginx
    state: reloaded
```

Добавим шаблон `nginx.conf` в `templates/nginx.conf.j2`
```nginx
# {{ ansible_managed }}
events {
  worker_connections 1024;
}

http {
  server {
    listen       {{ nginx_listen_port }} default_server;
    server_name  default_server;
    root         /usr/share/nginx/html;

    location / {
    }
  }
}
```

Добавим переменную шаблонизации в `vars/main.yml`
```yml
nginx_listen_port: 8080
```

А теперь напишем правила установки `nginx`, копирования конфигов и вызова `handlers` в `tasks/main.yml`:
```yml
- name: NGINX | Install NGINX package
  apt:
    name: nginx
    state: latest
  notify:
    - restart_nginx
- name: NGINX | Create NGINX config file from template
  template:
    src: templates/nginx.conf.j2
    dest: /etc/nginx/nginx.conf
  notify: 
    - reload_nginx
```

В корень директории добавим `yml`, где вызывается данная роль.
```yaml
---
- name: NGINX | Install and configure NGINX
  hosts: nginx_0
  become: true
  roles:
    - nginx

```

Готово.

## 03. Проверка работы
Запускаем `vagrant up` и заходим на `control plane` машину.

```bash
vagrant@control:~$ cd ansible/
vagrant@control:~/ansible$ ansible-playbook playbook.yml 

PLAY [NGINX | Install and configure NGINX] ***************************************************************

TASK [Gathering Facts] ***********************************************************************************
ok: [nginx_0]

TASK [nginx : NGINX | Install NGINX package] *************************************************************
changed: [nginx_0]

TASK [nginx : NGINX | Create NGINX config file from template] ********************************************
changed: [nginx_0]

RUNNING HANDLER [nginx : restart_nginx] ******************************************************************
changed: [nginx_0]

RUNNING HANDLER [nginx : reload_nginx] *******************************************************************
changed: [nginx_0]

PLAY RECAP ***********************************************************************************************
nginx_0                    : ok=5    changed=4    unreachable=0    failed=0    skipped=0    rescued=0    i
gnored=0   
```


Проверяем работу NGINX
```bash
vagrant@control:~/ansible$ cat staging/hosts 
nginx_0 ansible_host=192.168.56.11 ansible_port=22 ansible_user=vagrant ansible_ssh_private_key_file=/home
/vagrant/.ssh/ansible
vagrant@control:~/ansible$ curl 192.168.56.11:8080
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

В выводе команды `curl` видно, что на порту 8080 для `nginx_0` поднят `nginx` сервис.
 