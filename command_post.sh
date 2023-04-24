#!/bin/bash

#-------------- Секция инициализации --------------

SYSTEMS=("rls" "zrdn" "spro" "kp")
SYSTEMSDESCR=("РЛС" "ЗРДН" "СПРО")
HBVARS=("-1" "-1" "-1")
LOGLINES=("0" "0" "0")

STRTODEL=20
STRMAXCOUNT=100

source "data.sh"
source "methods.sh"

SubsystemType="КП"
SubsystemLog="KP"
NumberOfSystem=0
SubsystemCanShoot=(0 0 0) # 0-ББ БР 1-Самолеты 2-Крылатые ракеты

commfile="$DirectoryCommLog/kp.log"
CheckStart

trap sigint_handler 2 		# Отлов сигнала остановки процесса. Если сигнал пойман, то вызывается функция ...

echo "Система $SubsystemType успешно инициализирована!"
echo "Система $SubsystemType успешно инициализирована!" | base64  >>$commfile

sltime=0;

#-------------- Секция работы КП --------------

while :
do
	sleep 1
	let sltime+=1

	#-------------- Секция вывода логов --------------

  if (( sltime%2 == 0))												# Если счётчик кратен 2м, то ...
	then
		i=0
		while (( $i < 3 ))												# Цикл по подсистемам
		do
			lines=`wc -l "$DirectoryCommLog/${SYSTEMS[$i]}.log" 2>/dev/null`; res=$? 	# Получаем количество строк в лог файле
			if (( res == 0 ))												# Если количество строк удалось получить, то
			then
				count=($lines)												# Получаем массив из строки с информацией о количестве строк
				count=${count[0]}											# Получаем первое число из массива
				((LinesToDisplay=$count-${LOGLINES[$i]}))		# Получаем количество строк, которое нужно вывести
				LOGLINES[$i]=$count 									# Определяем количество уже выведенных строк
				if (( $LinesToDisplay > 0))						# Если количество строк, которые нужно вывести, больше нуля, то ...
				then
					readedfile=`tail -n $LinesToDisplay $DirectoryCommLog/${SYSTEMS[$i]}.log 2>/dev/null`;result=$?	 # Считываем строки, которые нужно вывести
					if (( $result == 0 ))								# Если успешно считали, то ...
					then
						echo "$readedfile" | base64 -d		# Выводим декодированные строки
						echo "$readedfile" >> $commfile
					fi
				fi
			fi
			let i+=1
		done
	fi

	#-------------- Секция мониторинга состояния подсистем -------------

  if (( sltime%50 == 0))											# Если счётчик кратен 50ти, то ...
	then
		i=0
		while (( $i < 3 ))												# Цикл по подсистемам
		do
			readedfile=`tail $DirectoryComm/${SYSTEMS[$i]} 2>/dev/null`; result=$?			# Получаем значение из файла системы	
			if (( $result == 0 ))										# Если успешно считали, то ...									
			then
				if (( ${HBVARS[$i]} == $readedfile))	# Если это значение совпадает с значением из массива, то система зависла
				then
					echo "Система ${SYSTEMSDESCR[$i]} зависла"
					echo "Система ${SYSTEMSDESCR[$i]} зависла" >>$commfile
				fi
				HBVARS[$i]=$readedfile								# Обновляем значение массива
			else																		# Если неуспешно считали, то ошибка доступа к системе
				echo "Ошибка доступа к cиcтеме ${SYSTEMSDESCR[$i]}"
				echo "Ошибка доступа к cиcтеме ${SYSTEMSDESCR[$i]}" >>$commfile
			fi
			let i+=1
		done
	fi

	# delete old log entries

	#-------------- Секция контроля логов -------------

	COUNTLINES=("-1" "-1" "-1" "-1")
	if (( sltime%1800 == 0))
	then
		i=0
		while (( $i < 4 ))
		do
			lines=`wc -l "$DirectoryCommLog/${SYSTEMS[$i]}.log" 2>/dev/null`; res=$?	# Получаем количество строк в лог файле
			if (( res == 0 ))												# Если количество строк удалось получить, то
			then
				count=($lines)												# Получаем массив из строки с информацией о количестве строк
				count=${count[0]}											# Получаем первое число из массива
				let COUNTLINES[$i]=$count
			fi
			let i+=1
		done
	fi

  if (( sltime%3500 == 0))
	then
		i=0
		while (( $i < 4 ))
		do
			lines=`wc -l "$DirectoryCommLog/${SYSTEMS[$i]}.log" 2>/dev/null`; res=$?	# Получаем количество строк в лог файле
			if (( res == 0 ))												# Если количество строк удалось получить, то
			then
				sed -i '1,${COUNTLINES[$i]}d' "/tmp/GenTargets/CommLog/${SYSTEMS[$i]}.log"
			fi
			let i+=1
		done
	fi
done
