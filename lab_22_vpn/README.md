# VPN

### Задание

1. Между двумя виртуалками поднять vpn в режимах:
- tun
- tap
Описать в чём разница, замерить скорость между виртуальными
машинами в туннелях, сделать вывод об отличающихся показателях
скорости.

2. Поднять RAS на базе OpenVPN с клиентскими сертификатами,
подключиться с локальной машины на виртуалку.


### Инфраструктура

Поднимается две машины, которые будут использованы в качестве:
* VPN сервера
* VPN клиента

В целом найтрока на обоих машинах простая:
* установка пакетов (`iperf3, openvpn`)
* настройка `openvpn`
* добавление `systemd` юнита для `openvpn`

[server provision script](./1/server_provision.sh)
[client provision script](./1/client_provision.sh)

### tun/tap performance test

На `server` запускается `iperf3` в серверном режиме: `iperf3 -s &`
На `client` запускается `iperf3`: `iperf3 -c 10.10.10.1 -t 40 -i 5`

**iperf3 для tap mode** 

```bash
root@client:~# iperf3 -c 10.10.10.1 -t 40 -i 5
Connecting to host 10.10.10.1, port 5201
[  5] local 10.10.10.2 port 39862 connected to 10.10.10.1 port 5201
[ ID] Interval           Transfer     Bitrate         Retr  Cwnd
[  5]   0.00-5.00   sec  45.1 MBytes  75.7 Mbits/sec    0   2.18 MBytes       
[  5]   5.00-10.00  sec  45.0 MBytes  75.5 Mbits/sec  1074   1.04 MBytes       
[  5]  10.00-15.00  sec  43.8 MBytes  73.4 Mbits/sec    0   1.10 MBytes       
[  5]  15.00-20.00  sec  43.8 MBytes  73.4 Mbits/sec  135    727 KBytes       
[  5]  20.00-25.00  sec  42.5 MBytes  71.3 Mbits/sec    0    861 KBytes       
[  5]  25.00-30.00  sec  43.8 MBytes  73.4 Mbits/sec  107    808 KBytes       
[  5]  30.00-35.00  sec  45.0 MBytes  75.5 Mbits/sec    4    693 KBytes       
[  5]  35.00-40.00  sec  43.8 MBytes  73.4 Mbits/sec  113    608 KBytes       
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-40.00  sec   353 MBytes  74.0 Mbits/sec  1433             sender
[  5]   0.00-40.00  sec   350 MBytes  73.3 Mbits/sec                  receiver

iperf Done.
```

**iperf3 для tun mode**

В настройках vpn для этого режима будeт изменена только "dev" строка. 

```bash
root@client:~# iperf3 -c 10.10.10.1 -t 40 -i 5
Connecting to host 10.10.10.1, port 5201
[  5] local 10.10.10.2 port 45832 connected to 10.10.10.1 port 5201
[ ID] Interval           Transfer     Bitrate         Retr  Cwnd
[  5]   0.00-5.00   sec  42.7 MBytes  71.7 Mbits/sec  130    549 KBytes       
[  5]   5.00-10.00  sec  40.0 MBytes  67.1 Mbits/sec    0    602 KBytes       
[  5]  10.00-15.00  sec  40.2 MBytes  67.4 Mbits/sec  207    373 KBytes       
[  5]  15.00-20.00  sec  40.9 MBytes  68.6 Mbits/sec   99    378 KBytes       
[  5]  20.00-25.00  sec  41.0 MBytes  68.7 Mbits/sec  195    208 KBytes       
[  5]  25.00-30.00  sec  39.2 MBytes  65.7 Mbits/sec   67    218 KBytes       
[  5]  30.00-35.00  sec  39.0 MBytes  65.5 Mbits/sec   85    157 KBytes       
[  5]  35.00-40.00  sec  40.0 MBytes  67.1 Mbits/sec   19    213 KBytes       
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-40.00  sec   323 MBytes  67.7 Mbits/sec  802             sender
[  5]   0.00-40.01  sec   321 MBytes  67.2 Mbits/sec                  receiver

iperf Done.
```

**Выводы**

Для tun mode скорость передачи чуть ниже "67Mb vs 73Mb" из-за накладных расходов в userspace.

### RAS

Здесь используется только одна машина в `vagrant`.
Скрипт инициализации следующий: [provision script](./2/provision.sh)

В целом настройка выглядит так:
* Генерация сертификатов (серверных и клиентского)
* Настройка серверной части `openvpn`
* Копирование сертификатов клиента и запуск `openvpn` клиента с определенным конфигом.
``

Конфиг для клиента здесь: [file](./2/client/client.conf). В этой же папке и будут необходимые сертификаты после запуска `vagrant up`.

**Запуск**

**NOTE** Важно перед запуском добавить строчку для маршрутизации к машине в virtualbox: `sudo ip route add 192.168.56.0/24 dev vboxnet0`

```bash
>>> sudo openvpn --config client.conf
2023-12-09 21:16:46 WARNING: Compression for receiving enabled. Compression has been used in the past to break encryption. Sent packets are not compressed unless "allow-compression yes" is also set.
2023-12-09 21:16:46 --cipher is not set. Previous OpenVPN version defaulted to BF-CBC as fallback when cipher negotiation failed in this case. If you need this fallback please add '--data-ciphers-fallback BF-CBC' to your configuration and/or add BF-CBC to --data-ciphers.
2023-12-09 21:16:46 OpenVPN 2.5.5 x86_64-pc-linux-gnu [SSL (OpenSSL)] [LZO] [LZ4] [EPOLL] [PKCS11] [MH/PKTINFO] [AEAD] built on Jul 14 2022
2023-12-09 21:16:46 library versions: OpenSSL 3.0.2 15 Mar 2022, LZO 2.10
2023-12-09 21:16:46 TCP/UDP: Preserving recently used remote address: [AF_INET]192.168.56.10:1207
2023-12-09 21:16:46 Socket Buffers: R=[212992->212992] S=[212992->212992]
2023-12-09 21:16:46 UDP link local (bound): [AF_INET][undef]:1194
2023-12-09 21:16:46 UDP link remote: [AF_INET]192.168.56.10:1207
2023-12-09 21:16:46 TLS: Initial packet from [AF_INET]192.168.56.10:1207, sid=c45e8251 8db3a981
2023-12-09 21:16:46 VERIFY OK: depth=1, CN=rasvpn
2023-12-09 21:16:46 VERIFY KU OK
2023-12-09 21:16:46 Validating certificate extended key usage
2023-12-09 21:16:46 ++ Certificate has EKU (str) TLS Web Server Authentication, expects TLS Web Server Authentication
2023-12-09 21:16:46 VERIFY EKU OK
2023-12-09 21:16:46 VERIFY OK: depth=0, CN=rasvpn
2023-12-09 21:16:46 Control Channel: TLSv1.3, cipher TLSv1.3 TLS_AES_256_GCM_SHA384, peer certificate: 2048 bit RSA, signature: RSA-SHA256
2023-12-09 21:16:46 [rasvpn] Peer Connection Initiated with [AF_INET]192.168.56.10:1207
2023-12-09 21:16:46 PUSH: Received control message: 'PUSH_REPLY,route 10.10.10.0 255.255.255.0,route 10.10.10.0 255.255.255.0,topology net30,ping 10,ping-restart 120,ifconfig 10.10.10.6 10.10.10.5,peer-id 0,cipher AES-256-GCM'
2023-12-09 21:16:46 OPTIONS IMPORT: timers and/or timeouts modified
2023-12-09 21:16:46 OPTIONS IMPORT: --ifconfig/up options modified
2023-12-09 21:16:46 OPTIONS IMPORT: route options modified
2023-12-09 21:16:46 OPTIONS IMPORT: peer-id set
2023-12-09 21:16:46 OPTIONS IMPORT: adjusting link_mtu to 1625
2023-12-09 21:16:46 OPTIONS IMPORT: data channel crypto options modified
2023-12-09 21:16:46 Data Channel: using negotiated cipher 'AES-256-GCM'
2023-12-09 21:16:46 Outgoing Data Channel: Cipher 'AES-256-GCM' initialized with 256 bit key
2023-12-09 21:16:46 Incoming Data Channel: Cipher 'AES-256-GCM' initialized with 256 bit key
2023-12-09 21:16:46 net_route_v4_best_gw query: dst 0.0.0.0
2023-12-09 21:16:46 net_route_v4_best_gw result: via 192.168.100.1 dev wlp0s20f3
2023-12-09 21:16:46 ROUTE_GATEWAY 192.168.100.1/255.255.255.0 IFACE=wlp0s20f3 HWADDR=08:8e:90:c3:c7:1f
2023-12-09 21:16:46 TUN/TAP device tun0 opened
2023-12-09 21:16:46 net_iface_mtu_set: mtu 1500 for tun0
2023-12-09 21:16:46 net_iface_up: set tun0 up
2023-12-09 21:16:46 net_addr_ptp_v4_add: 10.10.10.6 peer 10.10.10.5 dev tun0
2023-12-09 21:16:46 net_route_v4_add: 10.10.10.0/24 via 10.10.10.5 dev [NULL] table 0 metric -1
2023-12-09 21:16:46 net_route_v4_add: 10.10.10.0/24 via 10.10.10.5 dev [NULL] table 0 metric -1
2023-12-09 21:16:46 WARNING: this configuration may cache passwords in memory -- use the auth-nocache option to prevent this
2023-12-09 21:16:46 Initialization Sequence Completed
```


**Проверка** 

```bash
>>> ping -c 4 10.10.10.1 
PING 10.10.10.1 (10.10.10.1) 56(84) bytes of data.
64 bytes from 10.10.10.1: icmp_seq=1 ttl=64 time=1.18 ms
64 bytes from 10.10.10.1: icmp_seq=2 ttl=64 time=2.38 ms
64 bytes from 10.10.10.1: icmp_seq=3 ttl=64 time=1.76 ms
64 bytes from 10.10.10.1: icmp_seq=4 ttl=64 time=1.81 ms

--- 10.10.10.1 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3006ms
rtt min/avg/max/mdev = 1.178/1.781/2.381/0.425 ms
```

```bash
>>> ip r
default via 192.168.100.1 dev wlp0s20f3 proto dhcp metric 600 
10.10.10.0/24 via 10.10.10.5 dev tun0 
10.10.10.5 dev tun0 proto kernel scope link src 10.10.10.6 
192.168.56.0/24 dev vboxnet0 scope link 
```

`Ping` проходит к `10.10.10.1` и также добавлена запись в таблице маршрутизации.