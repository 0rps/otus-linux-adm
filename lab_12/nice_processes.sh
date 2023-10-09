#!/bin/bash

if [ -z "$*" ]; then
    echo "Run this script with two arguments: nice value for process A and nice value for process B.
Example: './nice_processes.sh 0 10'"; 
    exit 1
fi

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
echo ""
SECONDS=0
while true; do
    sleep 5
    SECONDS=$((SECONDS+5))
    echo "Passed $SECONDS seconds"
    echo ""
done

