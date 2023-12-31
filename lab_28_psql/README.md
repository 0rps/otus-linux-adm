# Репликация и резервное копирование СУБД PostgreSQL

### Задание

1) Настроить `hot_standby` репликацию с использованием слотов
2) Настроить резервное копирование с использованием `barman`

### Инфраструктура

Стенд для данного задания состоит из 3х хостов:
* master PostgreSQL instance
* slave PostgreSQL instance
* barman server

`Provision` осуществляется с помощью Ansible и соответствующих ролей.

### `hot_standby` репликация

Описание:
* На хостах `node1` и `node2` установить PostgreSQL
* (node1) Создать в `PostgreSQL` пользователя для репликации и разрешить подключаться под этим пользователем с `node2`
* (node1) Изменить параметры в `postgresql.conf`
* (node2) Остановить `PostgreSQL` и восстановить копию с `node1`
* (node2) Изменить `conninfo` для репликации в `postgresql.conf`


**Ansible file для node1**: [file](./provisioning/roles/postgres_master/tasks/main.yaml)
**Ansible file для node2**: [file](./provisioning/roles/postgres_slave/tasks/main.yaml)

##### Проверка

Создадим БД на `master` и проверим ее наличие на реплике.

```bash
postgres@node1:/root$ psql 
psql (15.5 (Ubuntu 15.5-0ubuntu0.23.10.1))
Type "help" for help.

postgres=#  CREATE DATABASE otus_test;
CREATE DATABASE
```

```bash
postgres@node2:/home/vagrant$ psql
psql (15.5 (Ubuntu 15.5-0ubuntu0.23.10.1))
Type "help" for help.
postgres=# \l
                                             List of databases
   Name    |  Owner   | Encoding | Collate |  Ctype  | ICU Locale | Locale Provider |   Access privileges   
-----------+----------+----------+---------+---------+------------+-----------------+-----------------------
 otus_test | postgres | UTF8     | C.UTF-8 | C.UTF-8 |            | libc            | 
 postgres  | postgres | UTF8     | C.UTF-8 | C.UTF-8 |            | libc            | 
 template0 | postgres | UTF8     | C.UTF-8 | C.UTF-8 |            | libc            | =c/postgres          +
           |          |          |         |         |            |                 | postgres=CTc/postgres
 template1 | postgres | UTF8     | C.UTF-8 | C.UTF-8 |            | libc            | =c/postgres          +
           |          |          |         |         |            |                 | postgres=CTc/postgres

postgres=# select * from pg_stat_wal_receiver;
-[ RECORD 1 ]---------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
pid                   | 8755
status                | streaming
receive_start_lsn     | 0/3000000
receive_start_tli     | 1
written_lsn           | 0/4422758
flushed_lsn           | 0/4422758
received_tli          | 1
last_msg_send_time    | 2023-12-31 14:29:44.818272+00
last_msg_receipt_time | 2023-12-31 14:29:44.820121+00
latest_end_lsn        | 0/4422758
latest_end_time       | 2023-12-31 14:25:44.237552+00
slot_name             | 
sender_host           | 192.168.57.11
sender_port           | 5432
conninfo              | user=replication password=******** channel_binding=prefer dbname=replication host=192.168.57.11 port=5432 fallback_application_name=15/main sslmode=prefer sslcompression=0 sslsni=1 ssl_min_protocol_version=TLSv1.2 gssencmode=prefer krbsrvname=postgres target_session_attrs=any
(4 rows)
```

БД существует, репликация прошла успешно.

### Резервное копирование с помощью `barman`

В данной части оперировать будем над `node1` и `barman` хостами.

Описание:
* (barman) Установим `barman`
* (barman) Сгенерируем SSH ключ для `barman` пользователя и добавим public часть на `node1`
* (barman) Настроим `barman` утилиту для возможности использования `postgresql` `replication` протокола.
* (node1) Создадим пользователя `barman` с правами SUPERUSER (т.к. данные права требуются для `switch_wal` и подобного рода операциях)
* (node1) Добавим правило для возможности подключения к PostgreSQL с `barman` хоста в pg_hba
* (node1) Также настроим `archive_command` для копирования WAL файлов после из финализации на хост с `barman`
* (node1) Сгенерируем SSH ключ для `postgres` пользователя и добавим public часть на `barman`

**Ansible file для node1**: [file](./provisioning/roles/barman_pg/tasks/main.yaml)
**Ansible file для barman**: [file](./provisioning/roles/barman_server/tasks/main.yaml)

Настройки `barman`: [barman.conf](./provisioning/roles/barman_server/templates/barman.conf.j2)
Настройки `barman` для подключения к `node1`: [barman.conf](./provisioning/roles/barman_server/templates/node.conf.j2)

##### Проверка

Cоздадим бд, таблицу и одну запись в ней на хосте `node1`.

```bash
postgres=# CREATE DATABASE otus;
CREATE DATABASE
postgres=# \c otus
You are now connected to database "otus" as user "postgres".
otus=# CREATE TABLE test (id int, name varchar(30));
INSERT INTO test VALUES (1, alex); 
CREATE TABLE
otus=# INSERT INTO test VALUES (1, 'alex');
INSERT 0 1


Проверка прав для репликации (`barman` host):
```bash
barman@barman:~$ psql -h 192.168.57.11 -U barman -c "IDENTIFY_SYSTEM" replication=1
      systemid       | timeline |  xlogpos  | dbname 
---------------------+----------+-----------+--------
 7318754441493877806 |        1 | 0/4422758 | 
(1 row)
```

Проверим настройки подключений для `barman`
```bash
# Switch WAL
barman@barman:~$ barman switch-wal node1
2023-12-31 14:32:18,334 [5357] barman.utils WARNING: Failed opening the requested log file. Using standard error instead.
The WAL file 000000010000000000000004 has been closed on server 'node1'
2023-12-31 14:32:18,462 [5357] barman.server INFO: The WAL file 000000010000000000000004 has been closed on server 'node1'

barman@barman:~$ barman cron 
Starting WAL archiving for server node1
Starting streaming archiver for server node1

barman@barman:/home/vagrant$ barman check node1
Server node1:
        PostgreSQL: OK
        superuser or standard user with backup privileges: OK
        PostgreSQL streaming: OK
        wal_level: OK
        replication slot: OK
        directories: OK
        retention policy settings: OK
        backup maximum age: FAILED (interval provided: 4 days, latest backup age: No available backups)
        backup minimum size: OK (0 B)
        wal maximum age: OK (no last_wal_maximum_age provided)
        wal size: OK (0 B)
        compression settings: OK
        failed backups: OK (there are 0 failed backups)
        minimum redundancy requirements: FAILED (have 0 backups, expected at least 1)
        pg_basebackup: OK
        pg_basebackup compatible: OK
        pg_basebackup supports tablespaces mapping: OK
        systemid coherence: OK (no system Id stored on disk)
        pg_receivexlog: OK
        pg_receivexlog compatible: OK
        receive-wal running: OK
        archiver errors: OK

```

Проверка выполнения создания резервной копии:
```bash
barman@barman:/home/vagrant$ barman backup node1
Starting backup using postgres method for server node1 in /var/lib/barman/node1/base/20231231T152653
Backup start at LSN: 0/14000000 (000000010000000000000013, 00000000)
Starting backup copy via pg_basebackup for 20231231T152653
WARNING: pg_basebackup does not copy the PostgreSQL configuration files that reside outside PGDATA. Please manually backup the following files:
        /etc/postgresql/15/main/postgresql.conf
        /etc/postgresql/15/main/pg_hba.conf
        /etc/postgresql/15/main/pg_ident.conf

Copy done (time: 2 seconds)
Finalising the backup.
Backup size: 36.6 MiB
Backup end at LSN: 0/15000000 (000000010000000000000014, 00000000)
Backup completed (start time: 2023-12-31 15:26:53.995917, elapsed time: 3 seconds)
Processing xlog segments from streaming for node1
        000000010000000000000012
        000000010000000000000013
```

Удалим на хосте `node1` базы `otus` и `otus_test` и восстановим из бэкапа.

```bash
otus=# \c postgres
You are now connected to database "postgres" as user "postgres".
postgres=# drop database otus;
DROP DATABASE
postgres=# drop database otus_test;
DROP DATABASE
```


```bash
barman@barman:/home/vagrant$ barman list-backup node1
node1 20231231T152653 - Sun Dec 31 15:26:56 2023 - Size: 36.6 MiB - WAL Size: 0 B


barman@barman:/home/vagrant$ barman recover node1 20231231T152653 /var/lib/postgresql/15/main --remote-ssh-comman "ssh postgres@192.168.57.11"                                                                       
Starting remote restore for server node1 using backup 20231231T152653
Destination directory: /var/lib/postgresql/15/main
Remote command: ssh postgres@192.168.57.11
Copying the base backup.
Copying required WAL segments.
Generating archive status files
Identify dangerous settings in destination directory.

WARNING
The following configuration files have not been saved during backup, hence they have not been restored.
You need to manually restore them in order to start the recovered PostgreSQL instance:

    postgresql.conf
    pg_hba.conf
    pg_ident.conf

Recovery completed (start time: 2023-12-31 15:30:23.157271+00:00, elapsed time: 9 seconds)
Your PostgreSQL server has been successfully prepared for recovery!
```


Перезагрузим `PostgreSQL` на `node1` и проверим данные
```bash

root@node1:/home/vagrant# systemctl restart postgresql
root@node1:/home/vagrant# su postgres
postgres@node1:/home/vagrant$ psql
could not change directory to "/home/vagrant": Permission denied
psql (15.5 (Ubuntu 15.5-0ubuntu0.23.10.1))
Type "help" for help.

postgres=# \c otus
You are now connected to database "otus" as user "postgres".
otus=# select * from test;
 id | name 
----+------
  1 | alex
(1 row)

```

Данные были успешно восстановлены.
