#!/bin/bash

#-------------- Проверка параметров запуска --------------

args=$# # Количество аргументов, переданных в скрипт

if (( args != 1 ))
then
	echo "Параметры запуска системы заданы неверно(1)!"
	exit 1
fi
CurrentSubsystemParamets=$1 # Тип системы: РЛС, ЗРДН или СПРО
if (( CurrentSubsystemParamets > 2 )) || (( CurrentSubsystemParamets < 0 ))
then
	echo "Параметры запуска системы заданы неверно(2)!"
	exit 2
fi

#-------------- Инициализация параметров систем --------------

declare -a TargetsId 				# Массив для целей
NoTarget=0
OldTarg=0

source "data.sh"
source "methods.sh"

SubsystemType="unknown"
SubsystemLog="unknown"
NumberOfSystem=0
SubsystemCanShoot=(0 0 0) 														# 0-ББ БР 1-Самолеты 2-Крылатые ракеты
SetSystemParametrs $CurrentSubsystemParamets 					# Установка параметров для системы

trap sigint_handler 2 																# Завершение работы системы по нажатию ctrl + C

commfile="$DirectoryCommLog/$SubsystemLog.log" 				# Директория для логов
mkdir $DirectoryComm >/dev/null 2>/dev/null						# Создание рабочей директории
mkdir $DirectoryCommLog >/dev/null 2>/dev/null				# Создание директории для логов
rm -rf $DirectoryComm/$SubsystemLog* 2>/dev/null			# Удаление логов с похожими именами
rm -rf $DirectoryCommLog/$SubsystemLog* 2>/dev/null

echo "Система $SubsystemType успешно инициализирована!" | base64 >>$commfile

HeartBeatInit $SubsystemLog

#-------------- Бесконечный цикл работы системы --------------

while :
do
	GetTargets		 																	# Получаем от генератора файлы целей

	if ((${#OldTarg[@]} != 0))											# Если массив предыдущих целей не пуст, то ...
	then
		for target in $OldTarg												# Проходим по прошлым целям
		do
			if [ "$target" ]
			then
				i=0
				while (( "$i" < "${#Targets[@]}" ))				# Цикл по количеству элементов в массиве текущих целей
				do
					if [[ "$target" == "${Targets[$i]}" ]]	# Если в текущей выборке попался файл цели, который уже рассматривался в прошлый раз
					then	
						Targets[$i]="ERROR"										# Заменяем название этого файла на ERROR
						break;
					fi
					let i+=1
				done
			fi
		done
	fi
	OldTarg=("${Targets[@]}")												# Обновляем массив старых целей

	#-------------- Проверка на промахи и попадания по целям --------------

	((countofElem=${#TargetsId[@]}/8)); 						# Количество элементов в массиве целей
	if (($countofElem > 0)) 												# Если есть известные цели (массив целей не пустой)
	then
		for target in $Targets												# Проходим по полученным от генератора целям
		do
			if [ "$target" ] && [ "$target" != "ERROR" ]
			then 
				IDTarget=`expr substr $target 13 6`;			# Получение ID цели
				i=0
				while (( "$i" < "$countofElem" ))					# Цикл по количеству элементов в массиве целей
				do
					if [[ "${TargetsId[0+8*$i]}" == "$IDTarget" ]] && ((${TargetsId[6+8*$i]} == 1)) # Если мы стреляли по цели и она вернулась и координаты изменились
					then
						echo "Промах по цели ID:${TargetsId[0+8*$i]}" | base64  >>$commfile		# Выдаём сообщение о промахе и сбрасываем флаг того, что стреляли
						let TargetsId[6+8*$i]=0
						break;
					fi
					let i+=1
				done
			fi
		done
		i=0
		while (( "$i" < "$countofElem" ))			# Цикл по количеству элементов в массиве целей
		do
			if ((${TargetsId[6+8*$i]} == 1))		# Если после предыдущего цикла остались цели с установленным флагом, что по ним стреляли
			then
				echo "Цель ID:${TargetsId[0+8*$i]} уничтожена" | base64  >>$commfile		# Выдаём сообщение об уничтожении и устанавливаем флаг "уничтожен"
				let TargetsId[6+8*$i]=2
			fi
			let i+=1
		done
	fi

	#-------------- Цикл по целям, полученным от генератора --------------

	for target in $Targets		# Проходим по полученным от генератора целям
	do
	 	if [ "$target" ] && [ "$target" != "ERROR" ]
	 	then 
	  	IDTarget=`expr substr $target 13 6`;															# Получение ID цели
	  	readedfile=`cat $DirectoryTargets/$target 2>/dev/null`;result=$?;	# Читаем файл
	  	if (( $result == 0 ))
	  	then
				XTarget=`echo $readedfile | cut -d',' -f 1 | cut -d'X' -f 2`;		# Координата X цели
				YTarget=`echo $readedfile | cut -d',' -f 2 | cut -d'Y' -f 2`;		# Координата Y цели
    	  NewTarget "8" "$IDTarget"; 																	# Проверяем цель на новизну
				idx=$returnIdx;

				#-------------- Обработка цели --------------

	  	 	if (( $idx == -1 )) 										# Если цель новая, то ...
	  	 	then
	    		TargetsId[0+8*$NoTarget]=$IDTarget		# ID цели
	    		TargetsId[1+8*$NoTarget]=$XTarget			# Координата X
	    		TargetsId[2+8*$NoTarget]=$YTarget			# Координата Y
	    		TargetsId[3+8*$NoTarget]=0						# Скорость цели по X
	    		TargetsId[4+8*$NoTarget]=0						# Скорость цели по Y
	    		TargetsId[5+8*$NoTarget]=-1						# Идентификатор цели
					TargetsId[6+8*$NoTarget]=0						# 0 - по цели не стреляли, 1 - стреляли, 2 - цель уничтожена
					TargetsId[7+8*$NoTarget]=0						# Было ли определено направление цели
					cIdx=$NoTarget 												# Индекс текущей цели
	    		let NoTarget+=1
	   		else
					cIdx=$idx 														# Индекс текущей цели

					#-------------- Обработка существующей цели --------------

					if (( ${TargetsId[1+8*$cIdx]} != ${XTarget} )) || (( ${TargetsId[2+8*$cIdx]} != ${YTarget} )) # Если координаты изменились, то ...
					then
						i=0
						while [[ "$i" < "$NumberOfSystem" ]]		# Цикл по системам конкретного типа
						do
							CheckCoverage $SubsystemType $i ${TargetsId[1+8*$cIdx]} ${TargetsId[2+8*$cIdx]};  det1=$?		# (1-я засечка)
							CheckCoverage $SubsystemType $i ${XTarget} ${YTarget};  det2=$?															# (2-я засечка)
							let i+=1
							if (($det1 == 1)) && (( $det2 == 1 ))																					# Если обе засечки
							then
								TId=-1
								if ((${TargetsId[3+8*$cIdx]} == 0 )) && ((${TargetsId[4+8*$cIdx]} == 0 ))		# Если скорости ещё не были определены	
								then
									let TargetsId[3+8*$cIdx]=(${XTarget}-${TargetsId[1+8*$cIdx]})							# Скорость по X
						  		let TargetsId[4+8*$cIdx]=(${YTarget}-${TargetsId[2+8*$cIdx]})							# Скорость по Y
									ClassifyTarget ${TargetsId[3+8*$cIdx]} ${TargetsId[4+8*$cIdx]}					# Идентифицируем цель по скорости
									let TId=$? 																																# Получили идентификатор цели
								fi
								if [[ $SubsystemType == "РЛС" ]] && (((${TId} == 0)) || ((${TargetsId[5+8*$cIdx]} == 0)))		# Если система - РЛС и цель - это ББ БР, то ...
								then
									if (( ${TargetsId[5+8*$cIdx]} == -1 ))	# Если до этого эту цель не идентифицировали
									then
										echo "$SubsystemType $i: Цель ID:${TargetsId[0+8*$cIdx]} обнаружена в (${TargetsId[1+8*$cIdx]}, ${TargetsId[2+8*$cIdx]}) и идентифицирована как Бал.блок (${TargetsId[3+8*$cIdx]}  ${TargetsId[4+8*$cIdx]})" | base64  >>$commfile 
										TargetsId[5+8*$cIdx]=${TId}	   				# Выдаём сообщение и устанавливаем идентификатор цели
									fi
									if (( ${TargetsId[7+8*$cIdx]} == 0 ))		# Если до этого направление цели не определяли, то
									then
										let delta_x=${XTarget}-${TargetsId[1+8*$cIdx]}
										let delta_y=${YTarget}-${TargetsId[2+8*$cIdx]}
										k=`echo "scale=3;$delta_y / $delta_x" | bc`		# Формируем уравнение прямой
										b=`echo "scale=3;$YTarget - $k * $XTarget" | bc`
										x=${SPRO[0+4*0]}											# Координаты и радиус СПРО
										y=${SPRO[1+4*0]}
										r=${SPRO[2+4*0]}
										# numerator=$((($k * $x) - $y + $b))		# Определяем числитель формулы
										# if [ $numerator -lt 0 ]								# Проверка на его положительность (эмуляция ABS)
										# then
										# 	numerator=$(($numerator * -1))
										# fi
										coef1=`echo "scale=3;4 * $k * $k * $b * $b" | bc`
										coef2=`echo "scale=3;4 * (1 + $k * $k) * ($b * $b - $r * $r)" | bc` 
										echo "-----------------------------------------------Тестируем значение дискриминанта---------------------"
										echo "коорд цели = ${TargetsId[2+8*$cIdx]} - ${YTarget} : ${TargetsId[1+8*$cIdx]} - ${XTarget}"
										echo "k=$k"
										echo "b=$b"
										echo "coef1=$coef1"
										echo "coef2=$coef2"
										result=`echo "$coef1>=$coef2" | bc`
										# distace=$(echo "scale=0; $numerator / sqrt($k*$k + 1)" | bc)	# Рассчёт расстояния от СПРО до прямой, по которой движется цель
										if [[ $result == 1 ]]					# Если расстояние от СПРО до прямой, по которой движеся цель, меньше радиуса зоны СПРО, то ...
										then
											echo $SubsystemType" $i: Цель ID:${TargetsId[0+8*$cIdx]} движется в направлении СПРО"
											echo $SubsystemType" $i: Цель ID:${TargetsId[0+8*$cIdx]} движется в направлении СПРО" | base64  >>$commfile
										fi
										let TargetsId[7+8*$cIdx]=1
									fi
								fi
								if [[ $SubsystemType == "СПРО" ]] && (((${TId} == 0)) || ((${TargetsId[5+8*$cIdx]} == 0)))		# Если система СПРО и цель - это ББ БР, то ...
								then
									if (( ${TargetsId[5+8*$cIdx]} == -1 ))					# Если до этого эту цель не идентифицировали
									then 
										echo "$SubsystemType $i: Цель ID:${TargetsId[0+8*$cIdx]} обнаружена в (${TargetsId[1+8*$cIdx]}, ${TargetsId[2+8*$cIdx]}) и идентифицирована как Бал.блок (${TargetsId[3+8*$cIdx]}  ${TargetsId[4+8*$cIdx]})" | base64  >>$commfile 
										TargetsId[5+8*$cIdx]=${TId}	   								# Выдаём сообщение и устанавливаем идентификатор цели
									fi
									if ((${SPRO[3+4*0]} > 0))			 								# Если есть чем стрелять
									then
										touch "$DestroyDirectory/${TargetsId[0+8*$cIdx]}"		# Стреляем, выводим сообщение и устанавливаем флаг того, что стреляли
										let SPRO[3+4*0]-=1
										echo "$SubsystemType $i отстрелялась по цели ID:${TargetsId[0+8*$cIdx]}. Оставшийся боезапас: ${SPRO[3+4*0]})" | base64  >>$commfile
										let TargetsId[6+8*$cIdx]=1
									fi
									if ((${SPRO[3+4*0]} == 0))			 								# Если боезапас исчерпан
									then
										# let SPRO[3+4*0]-=1				 										# Переход в режим обнаружения													
										echo "$SubsystemType $i: Боекомплект исчерпан! Переход в режим обнаружения." | base64  >>$commfile
									fi
								fi
								if [[ $SubsystemType == "ЗРДН" ]] && (((${TId} == 1)) || ((${TId} == 2)) || ((${TargetsId[5+8*$cIdx]} == 1)) || ((${TargetsId[5+8*$cIdx]} == 2)) )			# Если система ЗРДН и цель - это самолёт или к. ракета
								then
									if (( ${TargetsId[5+8*$cIdx]} == -1 ))					# Если до этого эту цель не идентифицировали
									then
										TargetsId[5+8*$cIdx]=${TId}										# Выдаём сообщение и устанавливаем идентификатор цели
										case ${TargetsId[5+8*$cIdx]} in
										1)
											echo "$SubsystemType $i: Цель ID:${TargetsId[0+8*$cIdx]} обнаружена в (${TargetsId[1+8*$cIdx]}, ${TargetsId[2+8*$cIdx]}) и идентифицирована как Самолет (${TargetsId[3+8*$cIdx]}  ${TargetsId[4+8*$cIdx]})" | base64  >>$commfile 
											;;
										2)
											echo "$SubsystemType $i: Цель ID:${TargetsId[0+8*$cIdx]} обнаружена в (${TargetsId[1+8*$cIdx]}, ${TargetsId[2+8*$cIdx]}) и идентифицирована как К.ракета (${TargetsId[3+8*$cIdx]}  ${TargetsId[4+8*$cIdx]})" | base64  >>$commfile 
											;;
										esac
									fi
									i_n=$((${i}-1))
									if ((${ZRDN[3+4*$i_n]} > 0))										# Если есть чем стрелять
									then
										touch "$DestroyDirectory/${TargetsId[0+8*$cIdx]}"		# Стреляем, выводим сообщение и устанавливаем флаг того, что стреляли
										let ZRDN[3+4*$i_n]-=1
										echo "$SubsystemType $i отстрелялась по цели ID:${TargetsId[0+8*$cIdx]}. Оставшийся боезапас: ${ZRDN[3+4*$i_n]})" | base64  >>$commfile
										let TargetsId[6+8*$cIdx]=1
									fi
									if ((${ZRDN[3+4*$i_n]} == 0))			 							# Если боезапас исчерпан
									then
										# let ZRDN[3+4*$i_n]-=1				 									# Переход в режим обнаружения													
										echo "$SubsystemType $i: Боекомплект исчерпан! Переход в режим обнаружения." | base64  >>$commfile
									fi
								fi
							fi
						done
	  				TargetsId[1+8*$idx]=${XTarget}	# Меняем координату X цели
						TargetsId[2+8*$idx]=${YTarget}	# Меняем координату Y цели
	  			fi
				fi
			fi
		fi
	done
	HeartBeat $SubsystemLog
	RandomSleep
done