#!/bin/ksh
#DebugTrace=NO
DebugTrace=YES

if [ "${DebugTrace}" == "YES" ]; then
	set -x
fi

LDAP_PORT=389
#START_SLAPD_CMD="su - ldap -c /export/home/ldap/start_slapd"
START_SLAPD_CMD="/ldapscripts/ldap_start start"
CORE_BACKUP_PATH=/var/ldap/testdata
TmpSearchResults=${CORE_BACKUP_PATH}/tmp.s_nanny_2.out
NannyLogFile=${CORE_BACKUP_PATH}/s_nanny_2.log

###############################################
# functions...
###############################################
SessionTimeStamp=''
SlapdLogDir=''
SLAPD_PID=NOT_RUNNING
MV=/usr/bin/mv

Trace()
{
	if [ ${DebugTrace} == YES ]; then
		echo $*
	fi
}

Log()
{
	Trace $*
	echo $* >>${NannyLogFile}
}

InitNewBackupDir()
{
	SessionTimeStamp=$(date -u '+%Y%m%d%H%M%SZ')
	if [ -d ${CORE_BACKUP_PATH:-"do not save core"} ]; then
		SlapdLogDir=${CORE_BACKUP_PATH}/${SessionTimeStamp}
	else
		SlapdLogDir=${SessionTimeStamp}
	fi

	# Try and create a new subdirectory for log/core/pstack... etc
	(mkdir ${SlapdLogDir} 2>&1) >>${NannyLogFile}
	if (( $? )); then
		Log "FATAL ERROR - Can't initialize log directory!"
		return 1
	fi
	
	return 0	# success
}

get_SLAPD_PID()
{
#	SLAPD_PS=`ps -eo pid,comm | grep slapd`
	SLAPD_PS=`ps -eo pid,comm | sed s'/^\s*//g' | grep slapd`
	if [ $? -eq 0 ]; then
		Trace "SLAPD_PS=${SLAPD_PS}"
		typeset -i tmp_PID=${SLAPD_PS%% *}
		SLAPD_PID=${tmp_PID}
		Trace "SLAPD_PID=${SLAPD_PID}" 
		return 0
	else	
		Trace "SLAPD_PS=${SLAPD_PS}"
		SLAPD_PID=NOT_RUNNING
		Trace "SLAPD_PID=${SLAPD_PID}" 
		return 1
	fi

	Log 'get_SLAPD_PID(): how did I get here?'
	return 1
}

save_core()
{
	if [ -f core ]; then
		Trace "core file found..." 
		if [ -d ${CORE_BACKUP_PATH:-"do not save core"} ]; then
			# save the core file...
			Log "Saving core to ${SlapdLogDir}"
			${MV} core ${SlapdLogDir}
#			(pstack ${SlapdLogDir}/core 2>&1) >${SlapdLogDir}/pstack.out
		else
			Log "Deleting core file"
			rm core
		fi	
	else
		Log "core file NOT found..."
	fi
}

slapd_is_started()
{
	cmd="ldapsearch -p ${LDAP_PORT:-389} -b cn=localhost -s base cn=* dn"
	Trace ${cmd}
	(${cmd} 2>&1) >${TmpSearchResults}
	RC=$?
	Trace "RC = ${RC}" 
	case ${RC} in
		0) return 0 ;;
		*) 
			if [ ${DebugTrace} == YES ]; then
				cat ${TmpSearchResults}
			fi
			return 1 ;;
	esac
	
	Log 'slapd_is_started(): how did I get here?'
	return 1
}

start_slapd()
{
	if InitNewBackupDir; then
		Log "Starting slapd at ${SessionTimeStamp}..."
	else
		return 1		# could not start
	fi
	
	Trace "${START_SLAPD_CMD:-slapd}" 
	(nohup ${START_SLAPD_CMD:-slapd} 2>&1) >${SlapdLogDir}/slapd.out &
	# wait no more than 30 seconds for slapd to start...
	let 'SEC=5'
	sleep $((SEC))
	while (( SEC < 30 )); do
		let 'SEC=SEC+1'
		Trace "$((SEC)) sec..."
		if get_SLAPD_PID; then
			Trace "SLAPD_PID = ${SLAPD_PID}"
			if slapd_is_started; then
				Trace 'start_slapd() -> 0'
				return 0
			fi
		else
			Log "FATAL ERROR - slapd won't start!"
			Trace 'start_slapd() -> 1'
			return 1
		fi
		sleep 1
	done
	
	Log "ERROR - Timed out waiting for slapd to start!"
	Trace 'start_slapd() -> 2'
	return 2
}

search_timeout()
{
	if [ -f ${TmpSearchResults} ]; then
		rm ${TmpSearchResults}
	fi
	
	cmd="ldapsearch -p ${LDAP_PORT:-389} -b cn=localhost -s base cn=* dn"
	Trace "${cmd}" 
	(${cmd} 2>&1) >${TmpSearchResults} &
	
	let 'SEC=0'
	while (( SEC < 30 )); do
		if [ -s ${TmpSearchResults} ]; then
			if [ ${DebugTrace} == YES ]; then
				cat ${TmpSearchResults}
			fi
			Trace "Search Finished in $((SEC)) sec." 
			rm ${TmpSearchResults}
			return 1
		fi
		sleep 1
		let 'SEC=SEC+1'
		Trace "$((SEC)) sec..."
	done

	# search did not return in < 30 sec.
	Log "Search took > 30 sec!" 
	return 0
}

kill_slapd()
{
#	Log "pstack -F $SLAPD_PID >${SlapdLogDir}/pstack.out"
#	(pstack -F $SLAPD_PID 2>&1) >${SlapdLogDir}/pstack.out
	
	Log "kill -9 $SLAPD_PID"
	kill -9 $SLAPD_PID	# be more insistant
	sleep 2
}

###############################################
# main - script starts here
###############################################

if InitNewBackupDir; then
	Log "$0 started at ${SessionTimeStamp}"
	Log "Logging to ${NannyLogFile}"
	sleep 1
else
	tail ${NannyLogFile}
	return 1		# could not start
fi

while (( 1 )); do						# loop forever
	if get_SLAPD_PID ; then				# if slapd is running...
		if search_timeout; then			# and search does not respond...
			kill_slapd;			# then kill the server
		else
			sleep 30			# else wait 30 sec. and try again...
		fi
	else						# else if slapd is not running...
		save_core;				# save the core if there is one
		if start_slapd; then			# if we can restart the server
			Log "Restarted Server"	# then OK - 
		else					# otherwise
			sleep 30			# FATAL ERROR wait 30 sec. and try again...
		fi
	fi
done

