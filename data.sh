#!/bin/bash

TempDirectory=/tmp/GenTargets
DirectoryTargets="$TempDirectory/Targets"
DestroyDirectory="$TempDirectory/Destroy"
DirectoryComm="$TempDirectory/Comm"
DirectoryCommLog="$TempDirectory/CommLog"
LogFile=$TempDirectory/GenTargets.log

MaxRLS=3
MaxZRDN=3
MaxSPRO=1

declare -a RLS  # x y a r fov
#1
RLS[0+5*0]=6000 # Координата X
RLS[1+5*0]=6000	# Координата Y
RLS[2+5*0]=270	# Азимут
RLS[3+5*0]=4500 # Дальность действия
RLS[4+5*0]=48	  # Угол обзора	
#2
RLS[0+5*1]=2500
RLS[1+5*1]=3600
RLS[2+5*1]=135
RLS[3+5*1]=3000
RLS[4+5*1]=120
#3
RLS[0+5*2]=5500
RLS[1+5*2]=3750
RLS[2+5*2]=225
RLS[3+5*2]=6000
RLS[4+5*2]=90

declare -a ZRDN  # x y r
#1
ZRDN[0+4*0]=6200
ZRDN[1+4*0]=3500
ZRDN[2+4*0]=600
ZRDN[3+4*0]=20
#1
ZRDN[0+4*1]=5500
ZRDN[1+4*1]=3750
ZRDN[2+4*1]=400
ZRDN[3+4*1]=20
#1
ZRDN[0+4*2]=4400
ZRDN[1+4*2]=3750
ZRDN[2+4*2]=650
ZRDN[3+4*2]=20

declare -a SPRO  # x y r
#1
SPRO[0+4*0]=3250
SPRO[1+4*0]=3400
SPRO[2+4*0]=1000
SPRO[3+4*0]=10