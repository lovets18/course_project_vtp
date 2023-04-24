#!/bin/bash

source "methods.sh" 2>/dev/null 
res=$? 

if [[ $res != 0 ]]
then
	echo "Невозможен запуск в интерпретаторе, отличном от BASH"
  exit 1
fi

CheckStart # Проверка возможности запуска

# Запуск РЛС
bash ./subsystems.sh 0 &
rls_pid=$!; echo "Запуск РЛС PID=$rls_pid"
ms=`echo "Запуск РЛС PID=$rls_pid"`
date=`date +'%F %T'`
#write_to_db system_db.db log_table "message, date" "'$ms', '$date'"
sleep 0.1

# Запуск ЗРДН
bash ./subsystems.sh 1 &
zrdn_pid=$!; echo "Запуск ЗРДН PID=$zrdn_pid"
ms=`echo "Запуск ЗРДН PID=$zrdn_pid"`
#write_to_db system_db.db log_table "message, date" "'$ms', '$date'"
sleep 0.1

# Запуск СПРО
bash ./subsystems.sh 2 &
spro_pid=$!; echo "Запуск СПРО PID=$spro_pid"
ms=`echo "Запуск СПРО PID=$spro_pid"`
#write_to_db system_db.db log_table "message, date" "'$ms', '$date'"
sleep 0.1

bash ./command_post.sh
echo "Завершение работы подсистемы РЛС";  disown $rls_pid 2>/dev/null; kill -9 $rls_pid 2>/dev/null;
ms=`echo "Завершение работы подсистемы РЛС"`
#write_to_db system_db.db log_table "message, date" "'$ms', '$date'" 
echo "Завершение работы подсистемы ЗРДН"; disown $zrdn_pid 2>/dev/null;  kill -9 $zrdn_pid 2>/dev/null;
ms=`echo "Завершение работы подсистемы ЗРДН"`
#write_to_db system_db.db log_table "message, date" "'$ms', '$date'"
echo "Завершение работы подсистемы СПРО"; disown $spro_pid 2>/dev/null;  kill -9 $spro_pid 2>/dev/null;
ms=`echo "Завершение работы подсистемы СПРО"`
#write_to_db system_db.db log_table "message, date" "'$ms', '$date'"
