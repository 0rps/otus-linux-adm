# Управление процессами

**Задание**

Реализовать 2 конкурирующих процесса по CPU. пробовать запустить с разными nice

## Реализация

### CPU нагрузка

В качестве CPU нагрузки можно взять скрипт, который в цикле инкрементирует переменную. При достижении определенного значения данный счетчик будет сброшен в 0 и выведено в термнал текущее кол-во сбросов с момента начала работы скрипта.

```bash

# Данная конструкция необходима, чтобы родительский скрипт выполнил все необходимые изменения.
sleep 1

COUNTER=0
RESET_COUNTER=0

while true; do
    COUNTER=$((COUNTER+1))
    if [ $COUNTER -eq 250000 ]; then
        RESET_COUNTER=$((RESET_COUNTER+1))
        echo "$$ - CPU bound load counter $RESET_COUNTER"
        COUNTER=0
    fi
done
```

### Управляющий скрипт

Данный скрипт будет запускать два дочерних процесса и задавать им приоритеты, которые были переданы в аргументах при запуске.
Также необходимо оба процесса назначить на одно и то же ядро, чтобы они конкурировали друг с другом за CPU ресурсы.

```bash

NC_A=$1
NC_B=$2

# Возьмем последнее ядро для запуска процессов
CORE=$(lscpu --online --parse=CPU | tail -n1)

# Запускаем процесы и получаем их PID
./cpu_bound_load.sh &
CHILD_A=$!
./cpu_bound_load.sh &
CHILD_B=$!

# При получении сигнала SIGINT убиваем процессы и выходим
trap "kill -9 $CHILD_A $CHILD_B && exit 0" SIGINT

# Ограничиваем процессы по ядру
echo "Bounding PIDs $CHILD_A and $CHILD_B to CPU $CORE"
taskset -p --cpu-list $CORE $CHILD_A
taskset -p --cpu-list $CORE $CHILD_B

# Устанавливаем приоритеты выполнения для процессов
echo "Renicing $CHILD_A to $NC_A"
renice $NC_A -p $CHILD_A 

echo "Renicing $CHILD_B to $NC_B"
renice $NC_B -p $CHILD_B

# Запускаем бесконечный цикл, который будет выводить время, прошедшее с момента запуска
SECONDS=0
while true; do
    sleep 5
    SECONDS=$((SECONDS+5))
    echo "Passed $SECONDS seconds"
done
```

## Запуск и проверка работы

**Запустим два процесса с приоритетами 5 и 15**

```bash
./nice_processes.sh 5 15
Bounding PIDs 54832 and 54833 to CPU 7
pid 54832's current affinity list: 0-7
pid 54832's new affinity list: 7
pid 54833's current affinity list: 0-7
pid 54833's new affinity list: 7
Renicing 54832 to 5
54832 (process ID) old priority 0, new priority 5
Renicing 54833 to 15
54833 (process ID) old priority 0, new priority 15

54832 - CPU bound load counter 1
54832 - CPU bound load counter 2
Passed 10 seconds

54832 - CPU bound load counter 3
54832 - CPU bound load counter 4
54832 - CPU bound load counter 5
54832 - CPU bound load counter 6
Passed 20 seconds

54832 - CPU bound load counter 7
54832 - CPU bound load counter 8
54832 - CPU bound load counter 9
54833 - CPU bound load counter 1
Passed 30 seconds
```

За 30 секунд процесс `54832` обнулил счетчик уже 9 раз, а `54833` - 1.

**Запустим два процесса с приоритетами 9 и 10**

```bash
./nice_processes.sh 9 10
Bounding PIDs 54965 and 54966 to CPU 7
pid 54965's current affinity list: 0-7
pid 54965's new affinity list: 7
pid 54966's current affinity list: 0-7
pid 54966's new affinity list: 7
Renicing 54965 to 9
54965 (process ID) old priority 0, new priority 9
Renicing 54966 to 10
54966 (process ID) old priority 0, new priority 10

54965 - CPU bound load counter 1
54966 - CPU bound load counter 1
Passed 10 seconds

54965 - CPU bound load counter 2
54966 - CPU bound load counter 2
54965 - CPU bound load counter 3
54966 - CPU bound load counter 3
Passed 20 seconds

54965 - CPU bound load counter 4
54966 - CPU bound load counter 4
54965 - CPU bound load counter 5
54965 - CPU bound load counter 6
Passed 30 seconds

54966 - CPU bound load counter 5
54965 - CPU bound load counter 7
54966 - CPU bound load counter 6
54965 - CPU bound load counter 8
Passed 40 seconds

54966 - CPU bound load counter 7
54965 - CPU bound load counter 9
54966 - CPU bound load counter 8
54965 - CPU bound load counter 10
Passed 50 seconds

54965 - CPU bound load counter 11
54966 - CPU bound load counter 9
54965 - CPU bound load counter 12
54966 - CPU bound load counter 10
Passed 60 seconds
```

Выше видно, что разница в работе между двумя процесами в данном тесте стала видна только после 30 секунд работы.
