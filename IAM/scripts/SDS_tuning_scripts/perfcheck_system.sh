#!/bin/ksh

# perfcheck_system.sh
#
# Last Updated: 04/03/2012 B Matteson
# Description:
#   Shell script to gather tuning information for your system.
# Usage:
#   This script should be run as root. Output can  be redirected to a 
#   file to send to support if needed.
# for example
# ./perfcheck_system.sh >/tmp/perfcheck_system.out 2>&1


# Stop if we're not root
if [ "`id -u`" != "0" ]; then
	echo "ERROR: This script should be run as root."
	exit 1;
fi

# Now we need to determine the OS
OS=`uname -s`


echo "*******************************"
echo "perfcheck_system.sh"
uname -a
date
echo "*******************************"

echo
echo "---------------------------"
echo "Memory"
echo "---------------------------"

if [ "$OS" = "AIX" ]; then
	prtconf | grep Memory
else if [ "$OS" = "SunOS" ]; then
	prtconf | grep Memory
else if [ "$OS" = "Linux" ]; then
	cat /proc/meminfo | grep MemTotal
else if [ "$OS" = "HP-UX" ]; then
	# is this really the only way to get physical RAM on HP??
	grep Physical /var/adm/syslog/syslog.log | awk '{print $6 $7 $8}'
fi
echo
echo "---------------------------"
echo "Swap"
echo "---------------------------"
if [ "$OS" = "AIX" ]; then
	lsps -s
else if [ "$OS" = "SunOS" ]; then
	swap -l
else if [ "$OS" = "Linux" ]; then
	swapon -s
else if [ "$OS" = "HP-UX" ]; then
	swapinfo
fi

echo
echo "---------------------------"
echo "Processor Information"
echo "---------------------------"
if [ "$OS" = "AIX" ]; then
	for i in `lscfg | grep proc | cut -d' ' -f 2`
	do
		echo $i
		lsattr -l $i -E
	done
else if [ "$OS" = "HP-UX" ]; then
	if type machinfo > /dev/null 2>&1; then
		machinfo
	else if type ioscan > /dev/null 2>&1; then
		ioscan -fnC processor
	fi
else if [ "$OS" = "Linux" ]; then
	cat /proc/cpuinfo
else if [ "$OS" = "SunOS" ]; then
	psrinfo -v
fi
	
echo
echo "---------------------------"
echo "Kernel bit level (32 or 64)"
echo "---------------------------"
if [ "$OS" = "AIX" ]; then
	prtconf | grep bit
else if [ "$OS" = "SunOS" ]; then
	/usr/bin/isainfo -kv
else if [ "$OS" = "Linux" ]; then
	$ARCH = `uname -i`
	if [ "$ARCH" = "i386" ]; then
		echo "uname -i returned 'i386' so it's a 32-bit system."
	else if [ "$ARCH" = "x86_64" ]; then
		echo "uname -i returned 'x86_64' so it's a 64-bit system."
	fi
else if [ "$OS" = "HP-UX" ]; then
	$BITS = `getconf KERNEL_BITS`
	echo "getconf says that this system has a ${BITS}-bit kernel."
fi


echo
echo "---------------------------"
echo "Kernel Parameters"
echo "---------------------------"
if [ "$OS" = "AIX" ]; then
	echo "Not applicable; shared memory is not tunable in AIX."
else if [ "$OS" = "SunOS" ]; then
	cat /etc/system | egrep "\s*set" | egrep -v "^\*"
else if [ "$OS" = "Linux" ]; then
	sysctl -a | egrep "kernel.(msg|shm)"
else if [ "$OS" = "HP-UX" ]; then
	kctune | egrep "sem|shm" 
fi

if type vmstat > /dev/null 2>&1; then
	echo "*******************************"
	date
	echo "vmstat"
	vmstat
	echo "*******************************"
fi

if type prstat > /dev/null 2>&1; then
	echo "*******************************"
	date
	echo "prstat"
	prstat
	echo "*******************************"
fi

if type iostat > /dev/null 2>&1; then
	echo "*******************************"
	date
	echo "iostat"
	iostat
	echo "*******************************"
fi

echo "*******************************"
date
echo "df -k"
df -k
echo "*******************************"
