#!/bin/bash
########################
# GLOBAL VARIABLES START
#

# Args
MAIL_ADDRESS=""

# for testing
#ROOT_FOLDER="./root"

ROOT_FOLDER=""
LOG_FOLDER="./log"

DATA_FOLDER_PATH="$ROOT_FOLDER/var/lib/bash_log_processor"
LOCK_FOLDER_PATH="$ROOT_FOLDER/var/run/lock"
TMP_FOLDER_PATH="$ROOT_FOLDER/tmp/bash_log_processor"

LOCK_FILE="$LOCK_FOLDER_PATH/bash_log_processor.lock"
DATA_FILE="$DATA_FOLDER_PATH/data"

MAIL_FILE="$TMP_FOLDER_PATH/mail"

TMP_OPERATION_FILE="$TMP_FOLDER_PATH/bash_log_processor.tmp"
MAIN_LOG_FILE="$TMP_FOLDER_PATH/bash_log_processor.source"
#
# GLOBAL VARIABLES END
######################

######################
# FUNCTION BLOCK START
#

# функция для выхода с ненулевым кодом, если предыдущая команда завершилась с ошибкой
fail_if_not_zero() {
  local result="$1"
  local message="$2"

  if [ $result -ne "0" ]; then
    echo "$message"
    exit 1
  fi
}


# читаем из файла время последней обработки
read_last_handled_time() {
  local last_handled_time=$(cat $DATA_FILE | grep LAST_HANDLED_TIME | awk '{print $2}')

  if [[ -z $last_handled_time ]]; then
    echo "0"
  else
    echo "$last_handled_time"
  fi
}

# пишем в файл время последней обработки
write_last_handled_time() {
  local last_handled_time="$1"
  local file_has_data=$(cat $DATA_FILE | grep LAST_HANDLED_TIME)

  if [[ -z $file_has_data ]]; then
    echo "LAST_HANDLED_TIME $last_handled_time" >> $DATA_FILE
  else
    sed -i "s/\(LAST_HANDLED_TIME \)[0-9]\+/\1${last_handled_time}/" $DATA_FILE
  fi
  fail_if_not_zero $? "Failed to write last handled time"
}

# находим все логи в папке и аггрегируем их в один файл (фильтруем по времени и добавляем unixtime)
find_and_aggregate_logs() {
  local last_handled_time="$1"
  truncate --size 0 $MAIN_LOG_FILE
  fail_if_not_zero $? "Failed to truncate main log file"

  local files=$(find $LOG_FOLDER -type f -name "*.log")
  fail_if_not_zero $? "Failed to find log files"
  for file in $files; do
    # фильтруем логи по времени, а также добавляем к каждой строке unixtime
    awk -v mintime=$last_handled_time '{
      # spliting date string: "[14/Aug/2019:04:12:10" => ["[14", "Aug", "2019", "04", "12", "10"]
      split($4,date,"[/ :]");
      # retrieving month index from month name: Aug => 8
      monthIndex = ((index("janfebmaraprmayjunjulaugsepoctnovdec",tolower(date[2]))-1)/3 + 1);
      # removing first "[" in "[14"
      day=substr(date[1], 2)
      # removing last "]" in "+0300]"
      tz=substr($5, 1, length($5)-1)
      # making string as "2019 08 14 04 12 10 +0300" (acceptable by mktime)
      unixtimeStr = (sprintf("%04d %02d %02d %02d %02d %02d %s", date[3], monthIndex, day, date[4], date[5], date[6], tz))
      # printing "<unixtime>, and other fields" if unixtime of the row is greater than "mintime"
      if (mktime(unixtimeStr) > mintime) print mktime(unixtimeStr), $0;
      }' $file >> $MAIN_LOG_FILE
      fail_if_not_zero $? "Failed to process log file $file"
    done
}

# получаем минимальное время из логов или берем его из аргемента. если он не 0
get_log_min_time() {
  # write to result last handled time
  local result="$1"
  local min_ts=$(awk '{print $1}' $MAIN_LOG_FILE | sort -nr | tail -n 1)
  fail_if_not_zero $? "Failed to get min time from log file"

  if [ $result -eq "0" ]; then
    result=$min_ts
  fi
  echo "$result"
}

# получаем максимальное время из логов
get_log_max_time() {
  local max_ts=$(awk '{print $1}' $MAIN_LOG_FILE | sort -nr | head -n 1)
  fail_if_not_zero $? "Failed to get max time from log file"
  echo "$max_ts"
}

print_title() {
  local MIN_TIME=$(date -u -d "@$1" '+%Y-%m-%d %H:%M:%S')
  local MAX_TIME=$(date -u -d "@$2" '+%Y-%m-%d %H:%M:%S')

  echo "LOG REPORT" >> $MAIL_FILE
  print_separator
  echo "START LOG TIME(UTC): $MIN_TIME" >> $MAIL_FILE
  echo "END LOG TIME(UTC):   $MAX_TIME" >> $MAIL_FILE
  echo "" >> $MAIL_FILE
}

print_header() {
  local header="$1"
  local length=${#header}
  local separator=$(printf '%*s' $length '' | tr ' ' '-')

  echo "" >> $MAIL_FILE
  echo "" >> $MAIL_FILE
  echo "$header" >> $MAIL_FILE
  echo "$separator" >> $MAIL_FILE
}

print_separator() {
  echo "---" >> $MAIL_FILE
}


print_frequency_distribution() {
  local header="$1"
  local awkvar="$2"

  # фильтруем поле в позиции awkvar и считаем количество для каждого уникального значения
  awk "{print $awkvar}" $MAIN_LOG_FILE | sort | uniq -c | sort -nr  | sed 's/^ *//' > $TMP_OPERATION_FILE
  fail_if_not_zero $? "Failed to aggregate frequency distribution"
  local maxlen=$(cat $TMP_OPERATION_FILE | head -n1 | awk '{print length($1)}')
  local template="%${maxlen}s|%s\n"

  print_header "$header"
  awk -v tpl=$template '{printf tpl, $1, $2;}' $TMP_OPERATION_FILE >> $MAIL_FILE
  fail_if_not_zero $? "Failed to print frequency distribution"
  print_separator
}

#
# FUNCTION BLOCK END
####################

##################
# ARGS BLOCK START
#

if [[ -z $1 ]]; then
  echo "Specify mail address"
  exit 1
fi

MAIL_ADDRESS="$2"

# ARGS BLOCK END
# ##############


#############################
# SETUP TRAP/LOCKS/DIRS START
#

# Убираем лок файл при выходе
trap "rm -f $LOCK_FILE" EXIT

# Проверка, что скрипт не запущен
if [ ! -f "$LOCK_FILE" ]; then
    mkdir -p "$LOCK_FOLDER_PATH"
    fail_if_not_zero $? "Failed to create lock folder"
    touch "$LOCK_FILE"
    fail_if_not_zero $? "Failed to create lock file"
else
    echo "Script is already running"
    exit 0
fi

# Инициализируем папку с временными файлами, если она не существует
if [ ! -d "$TMP_FOLDER_PATH" ]; then
    mkdir -p "$TMP_FOLDER_PATH"
else
    rm -rf "$TMP_FOLDER_PATH"/*
fi
fail_if_not_zero $? "Failed to initialize tmp folder"

# Инициализируем папку с данными, если она не существует
if [ ! -f "$DATA_FILE" ]; then
    mkdir -p "$DATA_FOLDER_PATH"    
    touch "$DATA_FILE"
    fail_if_not_zero $? "Failed to create data file"
fi

#
# SETUP TRAP/LOCKS/DIRS END
###########################


##################
# MAIN BLOCK START
#

# Последнее время обработки логов (читаем из конфига)
LAST_HANDLED_TIME=$(read_last_handled_time)

# Находим и обрабатываем логи с момента последней обработки
find_and_aggregate_logs $LAST_HANDLED_TIME

# Если нечего обрабатывать - выходим
LINES=$(wc -l $MAIN_LOG_FILE | awk '{print $1}')
if [ $LINES -eq "0" ]; then
  echo "No new logs"
  exit 0
fi

# Минимальное и максимальные времена логов
MIN_TIME=$(get_log_min_time $LAST_HANDLED_TIME)
MAX_TIME=$(get_log_max_time)

# печатаем заголовок с временем начала и конца временного промежутка логов
print_title $MIN_TIME $MAX_TIME

# аггрегация всех строк по IP, "$2" - позиция IP в строке
print_frequency_distribution "COUNT|IP" '$2'

# аггрегация всех строк по URL, "$8" - позиция URL в строке
print_frequency_distribution "COUNT|URL" '$8'

# аггрегация всех строк по HTTP_CODE, "$10" - позиция HTTP_CODE в строке
print_frequency_distribution "COUNT|HTTP_CODE" '$10'

# фильтруем и добавляем в письмо все строки с ошибками. Используем 'sed', хоть можно и использовать 'cut -c2-'
print_header "LINES WITH ERRORS"
awk '{ if ($10 >= 400 && $10 < 600) { $1=""; print $0; }}' $MAIN_LOG_FILE | sed 's/^ *//' >> $MAIL_FILE
fail_if_not_zero $? "Failed to print lines with errors"
print_separator 

# for testing
#cat $MAIL_FILE

mail -s "LOG REPORT" "$MAIL_ADDRESS" < $MAIL_FILE
fail_if_not_zero $? "Failed to send mail"

write_last_handled_time $MAX_TIME
#
# MAIN BLOCK END
################
