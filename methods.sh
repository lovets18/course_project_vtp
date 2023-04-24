#!/bin/bash

function CheckStart			# Функция проверки возможности запуска
{
	if [[ $EUID -eq 0 ]]
	then
		echo "Невозможен запуск с правами администратора"
		exit 1
	fi

	OS=`uname -s`
	if [[ $OS != "Linux" ]]
	then
	  echo "Невозможен запуск в ОС, отличной от Linux"
	  exit 1
	fi

	t1="1";
	t2="1";
	[[ $t1 == $t2 ]] 
	res=$?
	if [ $res != 0 ]
	then
	  echo "Невозможен запуск в интерпретаторе, отличном от BASH"
	  exit 1
	fi
}

sigint_handler() { echo "";echo "Завершение работы системы $SubsystemType" ; exit 0;} 

function GetTargets				# Функция получения списка целей
{
	Targets=`ls -tr $DirectoryTargets 2>/dev/null | tail -n 30`	# Сортированные данные целей
	result=$?;
	if (( $result != 0 ))
	then
		echo "Система не запущена!"
		exit 0
	fi
}

returnIdx=0;
function NewTarget		# Функция проверки на новизну цели
{
  # Если цель новая, возвращается -1, иначе возвращается индекс элемента
  sizeofElem="$1"
  idcurr="$2";

  ((countofElem=${#TargetsId[@]}/sizeofElem)); # TargetsId - это массив целей, sizeofElem - количество характеристик одной цели
  returnIdx=-1
  i=0
  while (( "$i" < "$countofElem" ))
  do
    if [[ "${TargetsId[0+$sizeofElem*$i]}" == "$idcurr" ]]
    then
      returnIdx=$i
      break;
    fi
    let i+=1
  done
}

# Функция классификации цели по скорости
function ClassifyTarget
{
  #0-ББ БР 1-Самолеты 2-Крылатые ракеты
  speedX=$1
	speedY=$2
	speed=$(echo "sqrt ( (($speedX*$speedX+$speedY*$speedY)) )" | bc)

	if ((( $speed > 50 )) && (( $speed < 250 )))
  then
    return 1
  fi

	if ((( $speed > 249 )) && (( $speed < 1000 )))
  then
    return 2
  fi

  if ((( $speed > 7999 )) && (( $speed < 10000 )))
  then
    return 0
  fi

  return 100
}


hbspro=0
hbzrdn=0
hbrls=0

function HeartBeatInit
{
	type="$1"
	filename=$DirectoryComm/$type
	echo "0" >$filename
	case $type in
  "rls")
		hbrls=0
    ;;
  "spro")
		hbspro=0
    ;;
  "zrdn")
		hbzrdn=0
  esac
}

function HeartBeat
{
	type="$1"

	case $type in
  "rls")
		let hbrls+=1
		echo "$hbrls" > "$filename.log"
    ;;
  "spro")
 		let hbspro+=1
		echo "$hbspro" > "$filename.log"
    ;;
  "zrdn")
		let hbzrdn+=1
		echo "$hbzrdn" > "$filename.log"
  esac
}

function RandomSleep
{
	rand=$((RANDOM%5+5))
	sltime=$(echo "$rand/10" | bc -l);
	sleep $sltime
}






function write_to_db 
{ 
	# Параметры функции: 
	# $1 - название базы данных 
	# $2 - название таблицы 
	# $3 - столбцы, в которые необходимо записать информацию, разделенные запятыми 
	# $4 - значения для записи, разделенные запятыми и обернутые в кавычки  
	# Строим SQL-запрос: 
	local query="INSERT INTO $2 ($3) VALUES ($4);"  
	# Запускаем SQLite и выполняем запрос: 
	sqlite3 $1 "$query" 
}











# Функция установки параметров системы
function SetSystemParametrs
{
	local cType=$1; 
	case $cType in
	0)	# РЛС
		SubsystemType="РЛС"
		SubsystemLog="rls"
		NumberOfSystem=$MaxRLS
		SubsystemCanShoot=(0 0 0) #0-ББ БР 1-Самолеты 2-Крылатые ракеты
		;;
	1)	# ЗРДН
		SubsystemType="ЗРДН"
		SubsystemLog="zrdn"
		NumberOfSystem=$MaxZRDN
		SubsystemCanShoot=(0 1 1) #0-ББ БР 1-Самолеты 2-Крылатые ракеты
		;;
	2)	# СПРО
		SubsystemType="СПРО"
		SubsystemLog="spro"
		NumberOfSystem=$MaxSPRO
		SubsystemCanShoot=(1 0 0) #0-ББ БР 1-Самолеты 2-Крылатые ракеты
		;;
  esac
}


function CheckSectorCoverage()
{
	local i=$1
	local X=$2
	local Y=$3

	((x1=-1*${RLS[0+5*$i]}+$X))	# Получение координаты X относительно РЛС
	((y1=-1*${RLS[1+5*$i]}+$Y)) # Получение координаты Y относительно РЛС

	local r1=$(echo "sqrt ( (($x1*$x1+$y1*$y1)) )" | bc) # Высчитываем расстояние цели до РЛС

	if (( $r1 <= ${RLS[3+5*$i]} ))
	then
	  local fi=$(echo | awk " { x=atan2($y1,$x1)*180/3.14; print x}"); fi=(${fi/\.*}); # Рассчитываем угол от -pi до pi для цели
	  if [ "$fi" -lt "0" ]
	  then
	   	((fi=360+$fi))	   # Если меньше нуля, то добавляем 360 градусов
	  fi

 	  ((fimax=${RLS[2+5*$i]}+${RLS[4+5*$i]}/2-90)); # Получаем углы сектора обзора
	  ((fimin=${RLS[2+5*$i]}-${RLS[4+5*$i]}/2-90));
 	  if (( $fi <= $fimax )) && (( $fi >= $fimin ))	# Если угол направления цели попадает в сектор
	  then
	   	return 1 # Возвращаем 1, если цель попала в сектор
	  fi
	fi
	return 0	# Возвращаем 0, если цель не попала в сектор
}

function CheckCirclerCoverage()
{
	local i=$1
	local X=$2
	local Y=$3
	local typeofvko=$4

	if (( typeofvko == 1 )) # Проверяем тип, если 1, то СПРО, иначе ЗРДН
	then
		((x1=-1*${SPRO[0+3*$i]}+$X))  # Получение координаты X относительно СПРО
		((y1=-1*${SPRO[1+3*$i]}+$Y))  # Получение координаты Y относительно СПРО
	else
		((x1=-1*${ZRDN[0+3*$i]}+$X))  # Получение координаты X относительно ЗРДН
		((y1=-1*${ZRDN[1+3*$i]}+$Y))  # Получение координаты Y относительно ЗРДН
	fi
	
	local r1=$(echo "sqrt ( (($x1*$x1+$y1*$y1)) )" | bc) # Высчитываем расстояние цели до РЛС

	if (( typeofvko == 1 )) # Проверяем тип, если 1, то СПРО, иначе ЗРДН
	then
		if [ "$r1" -le "${SPRO[2+3*$i]}" ]  # Если расстояние меньше радиуса обзора
		then
		  return 1
		fi
	else
		if [ "$r1" -le "${ZRDN[2+3*$i]}" ]  # Если расстояние меньше радиуса обзора
		then
		  return 1
		fi
	fi
	return 0  # Возвращаем 0, если цель не попала в обзор
}

# Проверка нахождения цели в зоне действия системы
function CheckCoverage
{
	local type="$1"	# Тип системы
	local no=$2 		# Номер объекта системы
	local Xm=$3			# Координата Х цели
	local Ym=$4 		# Координата Y цели

  ((X=$Xm/1000))
	((Y=$Ym/1000))

	case $type in
  "РЛС")
    CheckSectorCoverage $no $X $Y
	  spotted=$? # Результат (попала цель в обзор или нет)
	  return $spotted
    ;;
  "СПРО")
   	CheckCirclerCoverage $no $X $Y 1
	  spotted=$? # Результат (попала цель в обзор или нет)
	  return $spotted
    ;;
 	"ЗРДН")
    CheckCirclerCoverage $no $X $Y 2
	  spotted=$? # Результат (попала цель в обзор или нет)
	  return $spotted
  esac	
}