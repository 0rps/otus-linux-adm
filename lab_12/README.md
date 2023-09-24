# Управление процессами

**Задание**
* написать свою реализацию ps ax используя анализ /proc
* написать свою реализацию lsof
* ???? дописать обработчики сигналов в прилагаемом скрипте, оттестировать, приложить сам скрипт, инструкции по использованию
* реализовать 2 конкурирующих процесса по IO. пробовать запустить с разными ionice
* реализовать 2 конкурирующих процесса по CPU. пробовать запустить с разными nice

### `ps ax`

```bash

```

* PID -> proc/<PID>
* TTY -> proc/PID/fd/0 -> take from parent, take from fd, take from awk $7 from stat and decipher it with kernel 
* Command -> /proc/<PID>/cmdline (ctermid)
* cputime - userspace + kernelspace
ctermid

       Here are the different values that the s, stat and state output specifiers (header "STAT" or "S") will display to describe the state of a process:

               D    uninterruptible sleep (usually IO)
               I    Idle kernel thread
               R    running or runnable (on run queue)
               S    interruptible sleep (waiting for an event to complete)
               T    stopped by job control signal
               t    stopped by debugger during the tracing
               W    paging (not valid since the 2.6.xx kernel)
               X    dead (should never be seen)
               Z    defunct ("zombie") process, terminated but not reaped by its parent

       For BSD formats and when the stat keyword is used, additional characters may be displayed:

               <    high-priority (not nice to other users)
               N    low-priority (nice to other users)
               L    has pages locked into memory (for real-time and custom IO)
               s    is a session leader
               l    is multi-threaded (using CLONE_THREAD, like NPTL pthreads do)
               +    is in the foreground process group



What does associated terminal means







### `lsof`

### IO concurring processes

### CPU concurring processes
