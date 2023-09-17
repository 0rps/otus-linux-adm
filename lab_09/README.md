# Написать скрипт для CRON, который раз в час будет формировать письмо и отправлять на заданную почту.

Информация в письме:
* Список IP адресов (с наибольшим кол-вом запросов) с указанием кол-ва запросов c момента последнего запуска скрипта;
* Список запрашиваемых URL (с наибольшим кол-вом запросов) с указанием кол-ва запросов c момента последнего запуска скрипта;
* Ошибки веб-сервера/приложения c момента последнего запуска;
* Список всех кодов HTTP ответа с указанием их кол-ва с момента последнего запуска скрипта.
* Скрипт должен предотвращать одновременный запуск нескольких копий, до его завершения.
* В письме должен быть прописан обрабатываемый временной диапазон.

### Основная часть с обработкой логов

Данная функция принимает на вход время с предыдущего запуска скрипта. Это время будет использоваться для фильтрации логов.
Функция извлекает строки, трансформирует их, фильтрует и сохраняет в один временный файл, который в дальнейшем и используется для генерации отчета.
Функция использует `find $LOG_FOLDER -type f -name "*.log"` для поиска файлов с логами, затем запускается большой awk блок, который фильтрует логи по минимальному времени плюс конвертирует дату в unixtime (нужно как раз для фильтрации по времени, а также для извлечения максимального времени логов, которое будет сохранено в файл). unixtime записывается как первый параметр в строчку.

```bash
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
```

### Аггегации по IP/URL/etc
Для данных операций была написана одна функция, которая принимает на вход номер колонки, по которой нужно аггрегировать данные, а также заголовок. В качестве источника используется файл, полученный на предыдущем шаге.

```bash
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
```

### Ошибки веб-сервера
Они формируются путем фильтрации: 400 <= HTTP_CODE <= 599.

```bash
print_header "LINES WITH ERRORS"
awk '{ if ($10 >= 400 && $10 < 600) { $1=""; print $0; }}' $MAIN_LOG_FILE | sed 's/^ *//' >> $MAIL_FILE
fail_if_not_zero $? "Failed to print lines with errors"
print_separator 
```

### Обрабатываемый временной диапазон
Он формируется путем извлечения минимальной и максимальной даты из логов. Минимальная дата также может быть взять из файла, где хранится максимальная дата логов с прошлого запуска.


### Одновременный запуск скриптов
Одновременный запуск скриптов предотвращается использованием `lock` файла
```bash
if [ ! -f "$LOCK_FILE" ]; then
    mkdir -p "$LOCK_FOLDER_PATH"
    fail_if_not_zero $? "Failed to create lock folder"
    touch "$LOCK_FILE"
    fail_if_not_zero $? "Failed to create lock file"
else
    echo "Script is already running"
    exit 0
fi
```

После завершения скрипта файл удаляется. Чтобы этот файл удалялся всегда, то реализована конструкция `trap`: `trap "rm -f $LOCK_FILE" EXIT`.

### Сохранение и чтение даты последнего лога
Данная дата читается и сохраняется в отдельном файле:
```bash 
read_last_handled_time() {
  local last_handled_time=$(cat $DATA_FILE | grep LAST_HANDLED_TIME | awk '{print $2}')

  if [[ -z $last_handled_time ]]; then
    echo "0"
  else
    echo "$last_handled_time"
  fi
}

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

```

### Ошибки
В качестве функции проверки ошибок используется следующий код, который принимает код предыдущей команды и сообщение об ошибке, если код не равен 0
```bash
fail_if_not_zero() {
  local result="$1"
  local message="$2"

  if [ $result -ne "0" ]; then
    echo "$message"
    exit 1
  fi
}
```

### find/sed
* `find` - был использован в качестве утилит для поиска log файлов. 
* `sed`- был использован в качестве инструмента для манипуляции с `data` файлом (где хранится время последнего обработанного лога).

### Отсылка по почте
Для отсылки по почте был использован следующий код (MAIL_ADDRESS передается как аргумент командной строки):

```bash
mail -s "LOG REPORT" "$MAIL_ADDRESS" < $MAIL_FILE
```
