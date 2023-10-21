# Настройка мониторинга

**Задание**
Настроить дашборд с 4-мя графиками

* память;
* процессор;
* диск;
* сеть.

Настроить на одной из систем:
* prometheus и grafana

## Выполнение задания

Инфраструктура основана на задании про Ansible.
С помощью Vagrant конфигурируется 2 ноды(виртуальные машины):
* `monitoring` - нода, на которую будет установлен prometheus и grafana
* `control` - нода, на которую будет установлен Ansible и с которого над `monitoring` будут проводиться необходимые действия

### Vagrant конфигурация

Содержимое файла здесь: [Vagrantfile](./Vagrantfile)

На `control` ноду копируется Ansible playbook и provision скрипт, который занимается добавлением информации и `monitoring` ноде.
Содержимое скрипта здесь: [provisioner-control-node.sh](./provisioner-control-node.sh)

Provision скрипт для `monitoring` находится здесь [зкщмprovisioner-node.sh](./provisioner-node.sh) и он добавляет информацию о `control` ноде.
Также пробрасывается порт grafana на host систему (13000:3000).

### Ansible роль для `monitoring`

Данная Ansible роль выполняет следующие действия:
* Устанавливает prometheus
* Конфигурирует его через yaml файл
* Устанавливает grafana
* Сбрасывает пароль
* Добавляет prometheus как `data source`

```yaml
---
- name: Prometheus | Install
  apt:
    name: prometheus
    state: latest
    update_cache: yes
  notify:
    - restart_prometheus
- name: Prometheus | Copy config
  template:
    src: templates/prometheus.yml.j2
    dest: /etc/prometheus/prometheus.yml
  notify: 
    - restart_prometheus
- name: Grafana | Install gpg
  apt:
    name: gnupg,software-properties-common
    state: present
    update_cache: yes
    cache_valid_time: 3600
- name: Grafana | Add gpg hey
  apt_key:
    url: "https://packages.grafana.com/gpg.key"
    validate_certs: no
- name: Grafana | Add repository
  apt_repository:
    repo: "deb https://packages.grafana.com/oss/deb stable main"             
    state: present
    validate_certs: no
- name: Grafana | Install grafana
  apt:
    name: grafana
    state: latest
    update_cache: yes
    cache_valid_time: 3600
- name: Grafana | Add datasource
  template:
    src: templates/datasource.yaml.j2
    dest: /etc/grafana/provisioning/datasources/default.yaml
- name: Grafana | Start service grafana-server
  systemd:
    name: grafana-server
    state: started
    enabled: yes
- name: Grafana | Wait for service up
  uri:
    url: "http://127.0.0.1:3000"
    status_code: 200
  register: __result
  until: __result.status == 200
  retries: 120
  delay: 1
- name: Grafana | Change admin password for grafana gui
  shell : "grafana-cli admin reset-admin-password {{ grafana_admin_password }}"
  register: __command_admin
  changed_when: __command_admin.rc !=0
```

### Запуск системы

```bash
vagrant up
vagrant ssh monitoring

# >>> monitoring node shell
cd ansible
ansible-playbook playbook.yml
```

### Конфигурация grafana

В качестве дэшборда была загружена следующая конфигурация в виде json: (grafana configuration)[https://grafana.com/grafana/dashboards/15334-server-metrics-cpu-memory-disk-network/]

Отчет:
![Grafana](./images/grafana.png | width=750)
