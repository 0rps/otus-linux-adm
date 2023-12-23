# DNS

### Задание

**Задание 1**
* Взять за основу стенд `https://github.com/erlong15/vagrant-bind`
* Добавить еще один сервер `client2`
* Завести в зоне `dns.lab` имена:
  * `web1` - указывает на `client1`
  * `web2` - указывает на `client2`
* Завести еще одну зону newdns.lab и добавить запись
  * `www` - указывает на оба хоста `client1` и `client2`

**Задание 2** 
* Настроить `split-dns`
  * `client1` - видит обе зоны, но в зоне `dns.lab` только запись `web1`
  * `client2` - видит только зону `dns.lab`

### Немного о структуре репозитория и лабораторной

Репозиторий имеет 2 независимые директорий, в каждой из которых находится свой `Vagrantfile` и все остальные файлы.
Также `Часть 1` имеет только `client1`, т.к. хост второго клиента излишен и полностью повторяет логику первого.

После создания хостов дальнейшая настройка происходит средствами `vagrant -> ansible`.

### Задание 1

Схема выполнения данного задания следующая:
* Запустить `vagrant`, он запустит ansible после создания вирт. машин
* Будет инициализировано 3 машины (dns master, dns slave, client)
* Далее руками будут добавлены записи `web1` и `web2` для `dns.lab` и будет сделана проверка с `client`, что на `dns slave` эти записи тоже доехали
* Далее будет добавлена зона `newdns.lab` и будет сделана проверка через `client` хост

Стартовая конфигурация bind следующая:
```bash
// root zone
zone "." {
	type hint;
	file "/usr/share/dns/root.hints";
};

// zones like localhost
include "/etc/bind/zones.rfc1918";
// root's DNSKEY
include "/etc/bind/bind.keys";

// lab's zone
zone "dns.lab" {
    type master;
    allow-transfer { key "zonetransfer.key"; };
    file "/etc/bind/named.dns.lab";
};

// lab's zone reverse
zone "50.168.192.in-addr.arpa" {
    type master;
    allow-transfer { key "zonetransfer.key"; };
    file "/etc/bind/named.dns.lab.rev";
};
```

Проверим адрес `ns01.dns.lab` и `web1.dns.lab` с `client`:
```bash
vagrant@client:~$ dig @192.168.50.10 ns01.dns.lab

; <<>> DiG 9.18.19-1~deb12u1-Debian <<>> @192.168.50.10 ns01.dns.lab
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 46199
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: 65583d51e01391480100000065873d5746060a3e10b0b7f7 (good)
;; QUESTION SECTION:
;ns01.dns.lab.                  IN      A

;; ANSWER SECTION:
ns01.dns.lab.           3600    IN      A       192.168.50.10

;; Query time: 0 msec
;; SERVER: 192.168.50.10#53(192.168.50.10) (UDP)
;; WHEN: Sat Dec 23 20:04:39 UTC 2023
;; MSG SIZE  rcvd: 85



vagrant@client:~$ dig @192.168.50.10 web1.dns.lab

; <<>> DiG 9.18.19-1~deb12u1-Debian <<>> @192.168.50.10 web1.dns.lab
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 16829
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: 3d1673c4af1b62b80100000065873d7b9cdd4e26497293f4 (good)
;; QUESTION SECTION:
;web1.dns.lab.                  IN      A

;; AUTHORITY SECTION:
dns.lab.                600     IN      SOA     ns01.dns.lab. root.dns.lab. 2711201407 3600 600 86400 600

;; Query time: 4 msec
;; SERVER: 192.168.50.10#53(192.168.50.10) (UDP)
;; WHEN: Sat Dec 23 20:05:15 UTC 2023
;; MSG SIZE  rcvd: 115
```
Как видно выше: `ns01` известен, а `web1` - нет.

**Добавим записи web1/web2 в зону и увеличим serial**
```bash
$TTL 3600
$ORIGIN dns.lab.
@               IN      SOA     ns01.dns.lab. root.dns.lab. (
                            2711201408 ; serial
                            3600       ; refresh (1 hour)
                            600        ; retry (10 minutes)
                            86400      ; expire (1 day)
                            600        ; minimum (10 minutes)
                        )

                IN      NS      ns01.dns.lab.
                IN      NS      ns02.dns.lab.

; DNS Servers
ns01            IN      A       192.168.50.10
ns02            IN      A       192.168.50.11

;Web - uncomment and increase serial
web1            IN      A       192.168.50.15
web2            IN      A       192.168.50.16
```

Перезагрузим сервис и проверим через slave dns:

```bash
vagrant@client:~$ dig @192.168.50.11 web1.dns.lab

; <<>> DiG 9.18.19-1~deb12u1-Debian <<>> @192.168.50.11 web1.dns.lab
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 61720
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: 592afc808ae74d130100000065873e8edb6abb8b43c695c1 (good)
;; QUESTION SECTION:
;web1.dns.lab.                  IN      A

;; ANSWER SECTION:
web1.dns.lab.           3600    IN      A       192.168.50.15

;; Query time: 0 msec
;; SERVER: 192.168.50.11#53(192.168.50.11) (UDP)
;; WHEN: Sat Dec 23 20:09:50 UTC 2023
;; MSG SIZE  rcvd: 85
```

Запись была добавлена

**Теперь добавим новую зону**

```bash
www             IN      A       192.168.50.15
www             IN      A       192.168.50.16
```

Для master dns:
```bash
zone "newdns.lab" {
    type master;
    allow-transfer { key "zonetransfer.key"; };
    allow-update { key "zonetransfer.key"; };
    file "/etc/bind/named.newdns.lab";
};
```

Для slave dns:
```bash
zone "newdns.lab" {
    type slave;
    masters { 192.168.50.10; };
};
```

Проверим:
```bash
vagrant@client:~$ dig @192.168.50.11 web.newdns.lab

; <<>> DiG 9.18.19-1~deb12u1-Debian <<>> @192.168.50.11 web.newdns.lab
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 20292
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: 0980d48a5876b4490100000065873f898a978383548ad0ab (good)
;; QUESTION SECTION:
;web.newdns.lab.                        IN      A

;; AUTHORITY SECTION:
newdns.lab.             600     IN      SOA     ns01.dns.lab. root.dns.lab. 2711201007 3600 600 86400 600

;; Query time: 7 msec
;; SERVER: 192.168.50.11#53(192.168.50.11) (UDP)
;; WHEN: Sat Dec 23 20:14:01 UTC 2023
;; MSG SIZE  rcvd: 124

vagrant@client:~$ dig @192.168.50.10 web.newdns.lab

; <<>> DiG 9.18.19-1~deb12u1-Debian <<>> @192.168.50.10 web.newdns.lab
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 52739
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: 288c5a97885c64330100000065873f8dd3c8c4807f1c80f1 (good)
;; QUESTION SECTION:
;web.newdns.lab.                        IN      A

;; AUTHORITY SECTION:
newdns.lab.             600     IN      SOA     ns01.dns.lab. root.dns.lab. 2711201007 3600 600 86400 600
```

Зона была успешно добавлена.


### Задание 2

Все файлы, относящиеся к этому заданию, находятся в директорий `part2`.

Зона `dns.lab` была разделена на 2 части для двух клиентов:
```bash
;Web - uncomment and increase serial
web1            IN      A       192.168.50.15
web2            IN      A       192.168.50.16
```
и
```bash
;Web - uncomment and increase serial
web1            IN      A       192.168.50.15
```

Шаг с генерацией ключей для `access list`ов пропустим.


Конфигурация `master dns` выглядит следующим образом:
```bash
// Указание Access листов 
acl client { !key client2-key; key client-key; 192.168.50.15; };
acl client2 { !key client-key; key client2-key; 192.168.50.16; };

view "client1" {
    match-clients { client; };

    // dns.lab zone
    zone "dns.lab" {
        // Тип сервера — slave
        type slave;
        // Будет забирать информацию с сервера 192.168.50.10
        masters { 192.168.50.10 key client-key; };
    };

    // newdns.lab zone
    zone "newdns.lab" {
        type slave;
        masters { 192.168.50.10 key client-key; };
    };
};

view "client2" {
    match-clients { client2; };

    // dns.lab zone
    zone "dns.lab" {
        type slave;
        masters { 192.168.50.10 key client2-key; };
    };

    // dns.lab zone reverse
    zone "50.168.192.in-addr.arpa" {
        type slave;
        masters { 192.168.50.10 key client2-key; };
    };
};


view "default" {
    match-clients { any; };

    include "/etc/bind/zones.rfc1918";

    zone "." {
        type hint;
        file "/usr/share/dns/root.hints";
    };

    zone "dns.lab" {
        in-view "client2";
    };

    zone "50.168.192.in-addr.arpa" {
        in-view "client2";
    };
    
    zone "newdns.lab" {
        in-view "client1";
    };
};

```

Здесь были использованы access list и view для того, чтобы разным клиентам (разным по IP) выдавать разные результаты.

**NOTE:** Также здесь использованы конструкции `in-view`, т.к. нельзя использовать одни и те же файлы в разных `view` и bind выдает ошибку, что не может использовать для операции `write` уже открытый файл.

Далее проверки будут выполняться только с `slave dns`, чтобы проверить, что передача информации о зонах была успешна.

**Проверим с `client01`**
```bash
vagrant@client:~$ dig @192.168.50.11 web1.dns.lab +short
192.168.50.15
vagrant@client:~$ dig @192.168.50.11 web2.dns.lab +short
vagrant@client:~$ dig @192.168.50.11 www.newdns.lab +short
192.168.50.16
192.168.50.15
```
Как видно выше, клиенту доступны обе зоны, но в зоне dns.lab виден только один хост.


**Проверим с `client02`**
```bash
vagrant@client2:~$ dig @192.168.50.11 www.newdns.lab +short
vagrant@client2:~$ dig @192.168.50.11 web1.dns.lab +short
192.168.50.15
vagrant@client2:~$ dig @192.168.50.11 web2.dns.lab +short
192.168.50.16
```

А этому клиенту доступна только одна зона, но зато в `dns.lab` видны оба хоста.
