# Архитектура сетей

### Задание 

**Теоретическая часть**
* Найти свободные подсети;
* Посчитать сколько узлов в каждой подсети, включая свободные;
* Указать `broadcast` адрес для каждой подсети;
* Проверить, нет ли ошибок при разбиении.

**Практическая часть**
* Соединить офисы в сеть согласно схеме и настроить роутинг;
* Все сервера и роутеры должны ходить в инет черз `inetRouter`;
* Все сервера должны видеть друг друга;
* У всех новых серверов отключить дефолт на NAT (eth0), который vagrant поднимает для связи.

Сеть central
- 192.168.0.0/28     - directors
- 192.168.0.32/28    - office hardware
- 192.168.0.64/26    - wifi

Сеть office1
- 192.168.2.0/26      - dev
- 192.168.2.64/26     - test servers
- 192.168.2.128/26    - managers
- 192.168.2.192/26    - office hardware

Сеть office2
- 192.168.1.0/25      - dev
- 192.168.1.128/26    - test servers
- 192.168.1.192/26    - office hardware


Итого должны получиться следующие сервера:
* inetRouter
* centralRouter
* office1Router
* office2Router
* centralServer
* office1Server
* office2Server

### Теоретическая часть

**Central**

| Название | Сеть | Маска | Кол-во адресов| Первый адрес | Последний адрес | Broadcast адрес |
| --- | ---  | ---   | ---           | ---          | ---             | ---             |
| directors       | 192.168.0.0/28  | 255.255.255.240 | 14 | 192.168.0.1 | 192.168.0.14 | 192.168.0.15 |
| office hardware | 192.168.0.32/28 | 255.255.255.240 | 14 | 192.168.0.33 | 192.168.0.46 | 192.168.0.47 |
| wifi            | 192.168.0.64/26 | 255.255.255.192 | 62 | 192.168.0.65 | 192.168.0.126 | 192.168.0.127 |

**Office 1**

| Название | Сеть | Маска | Кол-во адресов| Первый адрес | Последний адрес | Broadcast адрес |
| --- | ---  | ---   | ---           | ---          | ---             | ---             |
| dev             | 192.168.2.0/26   | 255.255.255.192 | 62 | 192.168.2.1   | 192.168.2.62  | 192.168.1.63 |
| test servers    | 192.168.2.64/26  | 255.255.255.192 | 62 | 192.168.2.65  | 192.168.2.126 | 192.168.1.127 |
| managers        | 192.168.2.128/26 | 255.255.255.192 | 62 | 192.168.2.129 | 192.168.2.190 | 192.168.1.191 |
| office hardware | 192.168.2.192/26 | 255.255.255.192 | 62 | 192.168.2.193 | 192.168.2.254 | 192.168.1.255 |


**Office 2**

| Название | Сеть | Маска | Кол-во адресов| Первый адрес | Последний адрес | Broadcast адрес |
| --- | ---  | ---   | ---           | ---          | ---             | ---             |
| dev             | 192.168.1.0/25   | 255.255.255.128 | 126 | 192.168.1.1 | 192.168.1.126 | 192.168.1.127 |
| test servers    | 192.168.1.128/26 | 255.255.255.192 | 62  | 192.168.1.129 | 192.168.1.190 | 192.168.1.191 |
| office hardware | 192.168.1.192/26 | 255.255.255.192 | 62  | 192.168.1.193 | 192.168.1.254 | 192.168.1.255 |

**Свободные подсети**

* 192.168.0.16/28 
* 192.168.0.48/28
* 192.168.0.128/25
* 192.168.255.64/26
* 192.168.255.32/27
* 192.168.255.16/28
* 192.168.255.8/29  
* 192.168.255.4/30 


### Практическая часть

##### Обзор Vagrantfile и provisioning части

В `Vagrantile` описываем все хосты с необходимыми сетевыми интерфейсами.
Пример:
```ruby
  :office2Server => {
    :net => [
              {ip: "192.168.1.2",    adapter: 2,  netmask: "255.255.255.128",  virtualbox__intnet: "dev2-net"},
            ]
  }
```

В качестве `provisioning` части будет использоваться `shell`. в котором будет устанавливаться и запускать `ansible`.

```bash
          apt-get update
          apt-get install ansible -y  

          cd /vagrant
          ansible-playbook -i="#{ansible_tag}," -c local ./playbook.yml
          reboot
```

Все машины будут создаваться в порядке "от корня к листьям", чтобы на каждом уровне был доступ к интернету после перенастройки сетевых маршрутов.

В качестве `ansible_tag` используется либо название хоста машины, либо предопределенный тэг.

В конце происходит перезагрузка, чтобы убедиться, что конфигурация точно применилась.

##### Обзор Ansible playbook

Для всех хостов обязательно применяется следующая конфигурация
```yaml
- hosts: all
  tasks:
  - name: install packages (traceroute)
    apt:
      name: traceroute
      state: present
      update_cache: yes
  - name: disable default route
    template: 
      src: /vagrant/files/00-installer-config.yaml
      dest: /etc/netplan/00-installer-config.yaml
      owner: root
      group: root
      mode: 0600
    when: ansible_hostname != "inetRouter"
  - name: add default gateway
    template: 
      src: "/vagrant/files/50-vagrant_{{ansible_hostname}}.yaml"
      dest: /etc/netplan/50-vagrant.yaml
      owner: root
      group: root
      mode: 0600
  - name: apply netplan
    command: netplan apply
```

Здесь устанавливается `traceroute`, отключается дефолтный маршрут и копируется новая конфигурация маршрутов для каждого хоста и затем эта конфигурация применяется.

Для группы `routers` применяется конфиг, где включается маршрутизация пакетов.
```yaml
- hosts: routers
  tasks:
  - name: set up forward packages across routers
    sysctl:
      name: net.ipv4.conf.all.forwarding
      value: '1'
      state: present
```

Для `inetRouter` применяется следующий конфиг:
```yaml
- hosts: inetRouter
  become: true
  tasks:
  - name: disable ufw
    service:
      name: ufw
      state: stopped
      enabled: no
  - name: Set up NAT on inetRouter
    template: 
      src: "{{ item.src }}"
      dest: "{{ item.dest }}"
      owner: root
      group: root
      mode: "{{ item.mode }}"
    with_items:
      - { src: "/vagrant/files/inetRouter/iptables_rules.ipv4", dest: "/etc/iptables_rules.ipv4", mode: "0644" }
      - { src: "/vagrant/files/inetRouter/iptables_restore", dest: "/etc/network/if-pre-up.d/iptables", mode: "0755" }
  - name: apply iptables rules
    command: iptables-restore < /etc/iptables_rules.ipv4
  - name: set up forward packages across routers
    sysctl:
      name: net.ipv4.conf.all.forwarding
      value: '1'
      state: present
```

Отключается фаерволл, копируются и применяются правила для NAT:
```bash
*filter
:INPUT ACCEPT [90:8713]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [54:7429]
-A INPUT -p icmp -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -p tcp -m state --state NEW -m tcp --dport 22 -j ACCEPT
COMMIT

*nat
:PREROUTING ACCEPT [1:44]
:INPUT ACCEPT [1:44]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING ! -d 192.168.0.0/16 -o enp0s3 -j MASQUERADE
COMMIT
```

И включается форвардинг пакетов

##### Пример файла с маршрутами

Возьмем, например, конфигурацию для `centralRouter`:

```yaml
---
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s8:
      addresses:
      - 192.168.255.2/30
      routes:
      - to: 0.0.0.0/0
        via: 192.168.255.1
    enp0s9:
      addresses:
      - 192.168.0.1/28
    enp0s10:
      addresses:
      - 192.168.255.9/30
      routes:
      - to: 192.168.2.0/26
        via: 192.168.255.10
      - to: 192.168.2.64/26
        via: 192.168.255.10
      - to: 192.168.2.128/26
        via: 192.168.255.10
      - to: 192.168.2.192/26
        via: 192.168.255.10
    enp0s16:
      addresses:
      - 192.168.0.33/28
    enp0s17:
      addresses:
      - 192.168.255.5/30
      routes:
      - to: 192.168.1.0/25
        via: 192.168.255.6
      - to: 192.168.1.128/26
        via: 192.168.255.6
      - to: 192.168.1.192/26
        via: 192.168.255.6
    enp0s18:
      addresses:
      - 192.168.0.65/26
```

### Проверка

В качестве проверки возьмем 2 хоста и: 
* попингуем с них адрес `inetRouter` `192.168.255.1`.
* выполним для них `traceroute` до `ya.ru`:

В качестве подопытных машин возьмем:
* `office1Server`
* `office2Server`

**office1Server**
```bash

vagrant@office1Server:~$ ping -i 2 ya.ru
PING ya.ru (77.88.55.242) 56(84) bytes of data.
64 bytes from ya.ru (77.88.55.242): icmp_seq=1 ttl=57 time=44.8 ms
64 bytes from ya.ru (77.88.55.242): icmp_seq=2 ttl=57 time=45.4 ms
64 bytes from ya.ru (77.88.55.242): icmp_seq=3 ttl=57 time=46.6 ms

vagrant@office1Server:~$ traceroute ya.ru
traceroute to ya.ru (5.255.255.242), 30 hops max, 60 byte packets
 1  _gateway (192.168.2.129)  1.032 ms  1.714 ms  1.537 ms
 2  192.168.255.9 (192.168.255.9)  4.581 ms  4.453 ms  4.296 ms
 3  192.168.255.1 (192.168.255.1)  4.237 ms  5.214 ms  5.103 ms
 4  10.0.2.2 (10.0.2.2)  5.759 ms  5.946 ms  6.408 ms
 5  * * *
 6  * * *
 7  * * *
...
```

Как видим выше пакеты прошли через: 
* `office1Server` (192.168.2.129, подсеть `office1`) 
* `centralRouter` (192.168.255.9)
* `inetRouter` (192.168.255.1)


**office2Server**

```bash
vagrant@office2Server:~$ ping ya.ru
PING ya.ru (5.255.255.242) 56(84) bytes of data.
64 bytes from ya.ru (5.255.255.242): icmp_seq=1 ttl=57 time=40.8 ms
64 bytes from ya.ru (5.255.255.242): icmp_seq=2 ttl=57 time=42.3 ms
64 bytes from ya.ru (5.255.255.242): icmp_seq=3 ttl=57 time=44.0 ms


traceroute to ya.ru (5.255.255.242), 30 hops max, 60 byte packets
 1  _gateway (192.168.1.1)  1.498 ms  0.917 ms  0.745 ms
 2  192.168.255.5 (192.168.255.5)  2.037 ms  1.905 ms  2.282 ms
 3  192.168.255.1 (192.168.255.1)  4.588 ms  4.320 ms  4.198 ms
 4  10.0.2.2 (10.0.2.2)  5.049 ms  4.569 ms  4.450 ms
 5  * * *
 6  * * *
 7  * * *
 8  * * *
 9  * * *
10  * * *
11  * * *
12  * * *
13  * vla-32z3-ae1.yndx.net (93.158.172.21)  45.754 ms *

```

Пакеты прошли через:
* `office1Router` (192.168.1.1)
* `centralRouter` (192.168.255.5)
* `inetRouter` (192.168.255.1)
