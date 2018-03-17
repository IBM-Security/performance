#!/bin/ksh
#------------------------------------------------------------------------------
#
# Licensed Materials - Property of IBM Corp.
# (C) Copyright IBM Corp. 2007
#
# All Rights Reserved
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
# ABSTRACT:
#    This shell script is used to collect system monitoring data
#    related to the performance and resource usage of ibmslapd and
#    (possibly) any related DB2 processes
#
# This script borrows heavily from idsreplstatus.sh both because it is
#   well-written, as well as to maintain some consistency between Support
#   scripts.
# 
#
################################################################################
#
# perfcheck_ldap.ksh
#
# Last Updated: 04/03/2012 Total rewrite from scratch
# Description:
#  Shell script to gather tuning information for ldap.
#  Originally, this script required you to be root to be run, and didn't check:
#	1) Are anonymous binds allowed?
#	2) Does the server accept non-SSL connections?
#	3) Does the server listen on loopback for connections?
#  All these things can cause the ldap search commands to fail.
#
#  The new version of the script dynamically finds a good client and you can
#  bind or not as your server requires. Most of the options are similar to those
#  provided by idsldapsearch itself (with a few exceptions).   
#  In addition, you no longer need to be root to run this script (although you
#  will need to know a valid bind dn if your server does not allow anon binds).
################################################################################
#
#Usage: ./perfcheck_ldap.ksh [-?][-D <admin>] [-w <password>] [-Z] [-P <stashpwd>]
#	[-K <kdbfile>] [-h <host|IP>] [-p <port>][-o <output_file>][-r][-v "<version>"]
#
#-h                    Print usage
#
#-D <admindn>          Admin DN; required if anon binds are disabled
#
#-w <passwd>           Admin DN password	
#
#-Z                    Use if connecting to the server over SSL
#
#-P <stashpasswd>      Stash password if required
#
#-K <path_to_kdb>      Location of *.kdb file if connecting over SSL
#
#-H <hostname>         Pass in the hostname in cases where the server is bound to a
#                        specific ip (and not localhost). 
#
#-x                    Debug flag - turns ON the debug mode of this script.
#
#-o <file>             Output file.  If omitted, default location is /tmp/perfcheck_ldap.out
#
#-p <port>             Specify the ldap server port (default is 389)
#
#-r		       Enable searching for replication status attributes
#
#-v <version>          For systems with multiple installed versions.  Force the
#                         script to use a specific version
#
################################################################################


InitGlobalVars()
{
	if [[ ${DEBUG_FLAG} = TRUE ]]; then
		set -x
	fi

	HostName=$(uname -n)
	OS=$(uname -s)
	ReplAttrs="ibm-replicationChangeLDIF ibm-replicationLastActivationTime ibm-replicationLastChangeId ibm-replicationLastFinishTime ibm-replicationLastResult ibm-replicationLastResultAdditional ibm-replicationNextTime ibm-replicationPendingChangeCount ibm-replicationState ibm-replicationFailedChangeCount ibm-replicationperformance"

	if [[ -z "${OutputFile}" ]]; then
		OutputFile="/tmp/perfcheck_ldap.out"
	fi

	if [[ -f "${OutputFile}" ]]; then
		mv "${OutputFile}" "${OutputFile}.old"
	fi

	if [[ -n "$Replication" ]]; then
		if [[ -z "$AdminPw" ]]; then
			echo "Error: replication searches require an admin DN and password." >> ${OutputFile}
			echo "Error: replication searches require an admin DN and password."
			exit 2
		fi
	fi

	if [[ -n "${AdminDn}" ]]; then
		if [[ -z "${AdminPw}" ]]; then
			print "Error: -D was specified without -w." >> ${OutputFile}
			print "Error: -D was specified without -w."
			exit 2
		fi
	fi

	if [[ -n "${AdminPw}" ]]; then 
		if [[ -z "${AdminDn}" ]]; then
			print "Error: -w was specified without -D." >> ${OutputFile}
			print "Error: -w was specified without -D."
			exit 2
		fi
	fi

	if [[ "$AdminPw" = "?" ]]; then
		print "Please enter your password: "
		stty -echo
		read input
		stty echo
		AdminPw=${input}
		export AdminPw
	fi

	if [[ -n "${SslTrue}" ]]; then
		if [[ -z "${LdapPort}" ]]; then
			export LdapPort=636
		fi
	fi

	if [[ -n "${SslTrue}" ]]; then
		if [[ -z "${KeyDb}" ]]; then
			print "Error: when specifying the -Z flag, the -K flag must also be specified." >> ${OutputFile}
			print "Error: when specifying the -Z flag, the -K flag must also be specified."
			exit 2
		fi
	fi

	if [[ -n "${SslTrue}" ]]; then
		if [[ -f "${KeyDb}" ]]; then
			print "The key database was found." >> ${OutputFile}
		else
			print "Could not locate the key database file." >> ${OutputFile}
			print "Could not locate the key database file."
			exit 2
		fi
	fi

	if [[ -z "${LdapPort}" ]]; then
		export LdapPort=389
	fi

	if [[ -z "${Host}" ]]; then
		export Host="127.0.0.1"
	fi

	processId="$$"
}

###############################################################################
# CheckForRunningServer:
###############################################################################
# Not much point in monitoring if ibmslapd isn't even running
#
###############################################################################
CheckForRunningServer()
{
	unset PID
	PID=$(ps -ef | grep slapd | grep -v grep | awk '{print $2}')
	if [[ -z ${PID} ]]; then
		print "There doesn't appear to be a running ibmslapd server." >> ${OutputFile}
		print "Please make sure the ibmslapd process is running." >> ${OutputFile}
		print "There doesn't appear to be a running ibmslapd server."
		print "Please make sure the ibmslapd process is running and retry."
		exit 2
	else
		for processid in $PID
		do	export ibmslapd_pid="$processid"
			print "There is an ibmslapd process running under process id: $processid" >> ${OutputFile}
			print "There is an ibmslapd process running under process id: $processid"
		done
	fi
}

EchoLogCmd()
{
	if [[ ${DEBUG_FLAG} == TRUE ]]; then
		set -x
	fi

	print "==============================================" >> ${OutputFile}
	print "Running: $*" >> ${OutputFile}
	
	print -n "Date: " >> ${OutputFile}
	eval $DateCmd >> ${OutputFile}
	print "Running: $*"
	echo "----------------------------------------------" >> ${OutputFile}
	echo "" >> ${OutputFile}
	eval "$*" >> ${OutputFile}
	rc=$?
	echo "" >> ${OutputFile}
	echo "==============================================" >> ${OutputFile}
	if [[ "$rc" -gt "0" ]]; then
		print "Command: $* failed with error: $rc"
	else
		print "Command: $* ran successfully."
	fi
}

RunCmdsWithPassword()
{
	if [[ ${DEBUG_FLAG} == TRUE ]]; then
		set -x
	fi

	if [ -z "$1" ]; then
		print "Didn't get passed in any parameters."
		exit 2
	fi

	LogCmd="$1"
	CmdToRun="$2"
	
	echo "==============================================">> ${OutputFile}
	print "Running: $LogCmd" >> ${OutputFile}
	print -n "Date: " >> ${OutputFile}
	eval $DateCmd >> ${OutputFile}
	print "Running: $LogCmd"
	echo "----------------------------------------------">> ${OutputFile}
	echo "" >> ${OutputFile}
	#eval "$*" >> ${OutputFile}
	eval "$CmdToRun" >> ${OutputFile}
	rc=$?
	echo "" >> ${OutputFile}
	echo "==============================================" >> ${OutputFile}

	if [[ "$rc" -gt "0" ]]; then
		print "Command: $LogCmd failed with error: $rc"
	else
		print "Command: $LogCmd ran successfully."
	fi
}

GetVersionAndCommands()
{
	if [[ ${DEBUG_FLAG} == TRUE ]]; then
		set -x
	fi

	export DateCmd="date +\"%Y-%m-%d-%H:%M:%S\""
	#print "entering GetVersionAndCommands" >> ${OutputFile}
	# Linux commands 
	#
	if [[ "${OS}" == "Linux" ]]; then
		IBMDIR="ibm"
	else
		IBMDIR="IBM"
	fi
	
	if [[ -z "$LdapVersion" ]]; then
		if [[ -f /opt/${IBMDIR}/ldap/V6.3/sbin/ibmslapd ]]; then
			LdapVersion="6.3"
		elif [[ -f /opt/${IBMDIR}/ldap/V6.2/sbin/ibmslapd ]]; then
			LdapVersion="6.2"
		elif [[ -f /opt/${IBMDIR}/ldap/V6.1/sbin/ibmslapd ]]; then
			LdapVersion="6.1"
		elif [[ -f /opt/${IBMDIR}/ldap/V6.0/sbin/ibmslapd ]]; then
			LdapVersion="6.0"
		elif [[ -f /usr/ldap/sbin/ibmslapd || -f /opt/IBMldaps/bin/ibmslapd ]]; then
			LdapVersion="5.2"
		else
			print "Could not determine ldap version."
			exit 2
		fi
	fi

	if [[ "${OS}" == "Linux" ]]; then
		case $LdapVersion in
			6.3 ) 
					IDS_LDAP_SEARCH="/opt/ibm/ldap/V6.3/bin/idsldapsearch -L"
					;;
			6.2 ) 
					IDS_LDAP_SEARCH="/opt/ibm/ldap/V6.2/bin/idsldapsearch -L"
					;;
			6.1 ) 
					IDS_LDAP_SEARCH="/opt/ibm/ldap/V6.1/bin/idsldapsearch -L"
					;;
			6.0 )	
					IDS_LDAP_SEARCH="/opt/ibm/ldap/V6.0/bin/idsldapsearch -L"	
					;;
			5.2 )
					IDS_LDAP_SEARCH="/usr/ldap/bin/ldapsearch -L"
					;;
			5.1 )
					IDS_LDAP_SEARCH="/usr/ldap/bin/ldapsearch -L"
					;;
			* )
					print "Didn't recognize version.  Exiting ..."
					exit 2
					;;
		esac
	elif [[ "${OS}" == "SunOS" ]]; then
		case $LdapVersion in
			6.3 ) 
					IDS_LDAP_SEARCH="/opt/IBM/ldap/V6.3/bin/idsldapsearch -L"
					;;
			6.2 ) 
					IDS_LDAP_SEARCH="/opt/IBM/ldap/V6.2/bin/idsldapsearch -L"
					;;
			6.1 ) 
					IDS_LDAP_SEARCH="/opt/IBM/ldap/V6.1/bin/idsldapsearch -L"
					;;
			6.0 )	
					IDS_LDAP_SEARCH="/opt/IBM/ldap/V6.0/bin/idsldapsearch -L"	
					;;
			5.2 )
					IDS_LDAP_SEARCH="/opt/IBMldapc/bin/ldapsearch -L"
					;;
			5.1 )
					IDS_LDAP_SEARCH="/opt/IBMldapc/bin/ldapsearch -L"
					;;
			* )
					print "Didn't recognize version.  Exiting ..."
					exit 2
					;;
		esac
	else
		case $LdapVersion in
			6.3 ) 
					IDS_LDAP_SEARCH="/opt/IBM/ldap/V6.3/bin/idsldapsearch -L"
					;;
			6.2 ) 
					IDS_LDAP_SEARCH="/opt/IBM/ldap/V6.2/bin/idsldapsearch -L"
					;;
			6.1 ) 
					IDS_LDAP_SEARCH="/opt/IBM/ldap/V6.1/bin/idsldapsearch -L"
					;;
			6.0 )	
					IDS_LDAP_SEARCH="/opt/IBM/ldap/V6.0/bin/idsldapsearch -L"	
					;;
			5.2 )
					IDS_LDAP_SEARCH="/usr/ldap/bin/ldapsearch -L"
					;;
			5.1 )
					IDS_LDAP_SEARCH="/usr/ldap/bin/ldapsearch -L"
					;;
			* ) 
					print "Couldn't recognize version.  Exiting ..."
					exit 2
					;;
		esac
	fi

	if [[ -n "${SslTrue}" ]]; then
		if [[ -n "${AdminDn}" ]]; then
			export CnMonitorCmd="${IDS_LDAP_SEARCH} -Z -P '${StashPw}' -K ${KeyDb} -D ${AdminDn} -w '${AdminPw}' -h ${Host} -p ${LdapPort} -s base -b cn=monitor objectclass=*"
			export CnMonitorCmdPwd="${IDS_LDAP_SEARCH} -Z -P ******** -K ${KeyDb} -D ${AdminDn} -w ******** -h ${Host} -p ${LdapPort} -s base -b cn=monitor objectclass=*"
			export CnConnectionsCmd="${IDS_LDAP_SEARCH} -Z -P '${StashPw}' -K ${KeyDb} -D ${AdminDn} -w '${AdminPw}' -h ${Host} -p ${LdapPort} -s base -b cn=connections,cn=monitor objectclass=*"
			export CnConnectionsCmdPwd="${IDS_LDAP_SEARCH} -Z -P ******** -K ${KeyDb} -D ${AdminDn} -w ******** -h ${Host} -p ${LdapPort} -s base -b cn=connections,cn=monitor objectclass=*"
			export RootDseCmd="${IDS_LDAP_SEARCH} -Z -P '${StashPw}' -K ${KeyDb} -D ${AdminDn} -w '${AdminPw}' -h ${Host} -p ${LdapPort} -s base objectclass=*"
			export RootDseCmdPwd="${IDS_LDAP_SEARCH} -Z -P ******** -K ${KeyDb} -D ${AdminDn} -w ******** -h ${Host} -p ${LdapPort} -s base objectclass=*"
			export ReplSearchCmd="${IDS_LDAP_SEARCH} -Z -P '${StashPw}' -K ${KeyDb} -D ${AdminDn} -w '${AdminPw}' -h ${Host} -p ${LdapPort} -s sub objectclass=ibm-replicationAgreement $ReplAttrs"
			export ReplSearchCmdPwd="${IDS_LDAP_SEARCH} -Z -P ******** -K ${KeyDb} -D ${AdminDn} -w ******** -h ${Host} -p ${LdapPort} -s sub objectclass=ibm-replicationAgreement $ReplAttrs"
		else
			export CnMonitorCmd="${IDS_LDAP_SEARCH} -Z -P '${StashPw}' -K ${KeyDb} -h ${Host} -p ${LdapPort} -s base -b cn=monitor objectclass=*"
			export CnMonitorCmdPwd="${IDS_LDAP_SEARCH} -Z -P ******** -K ${KeyDb} -h ${Host} -p ${LdapPort} -s base -b cn=monitor objectclass=*"
			export CnConnectionsCmd="${IDS_LDAP_SEARCH} -Z -P '${StashPw}' -K ${KeyDb} -h ${Host} -p ${LdapPort} -s base -b cn,connections,cn=monitor objectclass=*"
			export CnConnectionsCmdPwd="${IDS_LDAP_SEARCH} -Z -P ******** -K ${KeyDb} -h ${Host} -p ${LdapPort} -s base -b cn,connections,cn=monitor objectclass=*"
			export RootDseCmd="${IDS_LDAP_SEARCH} -Z -P '${StashPw}' -K ${KeyDb} -h ${Host} -p ${LdapPort} -s base objectclass=*"
			export RootDseCmdPwd="${IDS_LDAP_SEARCH} -Z -P ******** -K ${KeyDb} -h ${Host} -p ${LdapPort} -s base  objectclass=*"
		fi
	else
		if [[ -n "${AdminDn}" ]]; then
			export CnMonitorCmd="${IDS_LDAP_SEARCH} -D ${AdminDn} -w '${AdminPw}' -h ${Host} -p ${LdapPort} -s base -b cn=monitor objectclass=*"
			export CnMonitorCmdPwd="${IDS_LDAP_SEARCH} -D ${AdminDn} -w ******** -h ${Host} -p ${LdapPort} -s base -b cn=monitor objectclass=*"
			export CnConnectionsCmd="${IDS_LDAP_SEARCH} -D ${AdminDn} -w '${AdminPw}' -h ${Host} -p ${LdapPort} -s base -b cn=connections,cn=monitor objectclass=*"
			export CnConnectionsCmdPwd="${IDS_LDAP_SEARCH} -D ${AdminDn} -w ******** -h ${Host} -p ${LdapPort} -s base -b cn=connections,cn=monitor objectclass=*"
			export RootDseCmd="${IDS_LDAP_SEARCH} -D ${AdminDn} -w '${AdminPw}' -h ${Host} -p ${LdapPort} -s base objectclass=*"
			export RootDseCmdPwd="${IDS_LDAP_SEARCH} -D ${AdminDn} -w ******** -h ${Host} -p ${LdapPort} -s base objectclass=*"
			export ReplSearchCmd="${IDS_LDAP_SEARCH} -D ${AdminDn} -w '${AdminPw}' -h ${Host} -p ${LdapPort} -s sub objectclass=ibm-replicationAgreement $ReplAttrs"
			export ReplSearchCmdPwd="${IDS_LDAP_SEARCH} -D ${AdminDn} -w ******** -h ${Host} -p ${LdapPort} -s sub objectclass=ibm-replicationAgreement $ReplAttrs"
		else
			export CnMonitorCmd="${IDS_LDAP_SEARCH} -h ${Host} -p ${LdapPort} -s base -b cn=monitor objectclass=*"
			export CnMonitorCmdPwd="${IDS_LDAP_SEARCH} -h ${Host} -p ${LdapPort} -s base -b cn=monitor objectclass=*"
			export CnConnectionsCmd="${IDS_LDAP_SEARCH} -h ${Host} -p ${LdapPort} -s base -b cn=connections,cn=monitor objectclass=*"
			export CnConnectionsCmdPwd="${IDS_LDAP_SEARCH} -h ${Host} -p ${LdapPort} -s base -b cn=connections,cn=monitor objectclass=*"
			export RootDseCmd="${IDS_LDAP_SEARCH} -h ${Host} -p ${LdapPort} -s base  objectclass=*"
			export RootDseCmdPwd="${IDS_LDAP_SEARCH} -h ${Host} -p ${LdapPort} -s base objectclass=*"
		fi
	fi

	# Add commands to be run below for each platform
	if [[ "${OS}" == "Linux" ]]; then
		export PsCmd="ps -ae -o user,pid,time,etime,thcount,vsz,pcpu,pmem,sched,comm,args | egrep '(slapd|db2sysc)' | grep -v grep"
		export VmstatCmd="vmstat 2 5"
		export SwapCmd="/sbin/swapon -s"
		export MemInfoCmd="cat /proc/meminfo"
		export SwapInfoCmd="cat /proc/swaps"
		export FreeCmd="free"
		export NetstatAnCmd="netstat -an | grep ${LdapPort}"
		export NetstatSCmd="netstat -s"
		export NetstatRnCmd="netstat -rn"
		export NetstatConns="netstat -tpe"
		export DfCmd="df -k"
		export IoStatCmd="iostat"
		export TopCmd="top -b -n 1"
		export UnameCmd="uname -a"
		export ReleaseCmd="cat /etc/*-release"
		export UlimitCmd="ulimit -a"
		export IdCmd="id"

		set -A runOnceArray "${UnameCmd}" "${ReleaseCmd}" "${NetstatRnCmd}" "${UlimitCmd}" "${IdCmd}" "${PsCmd}" "${VmstatCmd}" "${SwapCmd}" "${MemInfoCmd}" "${SwapInfoCmd}" "${FreeCmd}" "${NetstatAnCmd}" "${DfCmd}" "${IoStatCmd}" "${TopCmd}" "${NetstatSCmd}"
	fi


	if [[ "${OS}" == "SunOS" ]]; then
		# to add new monitoring commands, just add them here 
		export PsCmd="ps -ae -o user,pid,time,etime,rss,vsz,pcpu,pmem,zone,comm,args | egrep '(slapd|db2sysc)' | grep -v grep"
		export VmstatCmd="vmstat 2 5"
		export NetstatAnCmd="netstat -an | grep ${LdapPort}"
		export NetstatRnCmd="netstat -rn"
		export NetstatSCmd="netstat -s"
		export DfCmd="df -k"
		export IoStatCmd="iostat"
		export UnameCmd="uname -a"
		export UlimitCmd="ulimit -a"
		export IdCmd="id"

		set -A runOnceArray "${UnameCmd}" "${NetstatRnCmd}" "${UlimitCmd}" "${IdCmd}" "${PsCmd}" "${VmstatCmd}" "${NetstatAnCmd}" "${DfCmd}" "${IoStatCmd}" "${NetstatSCmd}"
	fi

	if [[ "${OS}" == "HP-UX" ]]; then
		export PsCmd="ps auxw | egrep '(slapd|db2sysc)' | grep -v grep"
		export VmstatCmd="vmstat 2 5"
		export NetstatAnCmd="netstat -an | grep ${LdapPort}"
		export NetstatRnCmd="netstat -rn"
		export NetstatSCmd="netstat -s"
		export DfCmd="df -k"
		export IoStatCmd="iostat 2 4"
		export UnameCmd="uname -a"
		export UlimitCmd="ulimit -a"
		export IdCmd="id"

		set -A runOnceArray "${UnameCmd}" "${NetstatRnCmd}" "${UlimitCmd}" "${IdCmd}" "${PsCmd}" "${VmstatCmd}" "${NetstatAnCmd}" "${DfCmd}" "${IoStatCmd}" "${NetstatSCmd}"
	fi

	if [[ "${OS}" == "AIX" ]]; then
		export PsCmd="ps -ae -o user,pid,time,etime,thcount,vsz,pcpu,pmem,sched,comm,args | egrep '(slapd|db2sysc)' | grep -v grep"
		export PsAexwwlCmd="ps aexwwl | grep slapd | grep -v grep"
		export VmstatCmd="vmstat -t 2 5"
		export NetstatAnCmd="netstat -an | grep ${LdapPort}"
		export NetstatSCmd="netstat -s"
		export NetstatRnCmd="netstat -rn"
		export DfCmd="df -k"
		export IoStatCmd="iostat -a"
		export UnameCmd="uname -a"
		export OsLevelr="oslevel -r"
		export OsLevels="oslevel -s"
		export UlimitCmd="ulimit -a"
		export IdCmd="id"
 
		set -A runOnceArray "${UnameCmd}" "${OsLevelr}" "${OsLevels}" "${NetstatRnCmd}" "${PsAexwwlCmd}" "${UlimitCmd}" "${IdCmd}" "${PsCmd}" "${VmstatCmd}" "${NetstatAnCmd}" "${DfCmd}" "${IoStatCmd}" "${NetstatSCmd}"
	fi
}

# This function is used to print the help for perfcheck_ldap.ksh
printusage()
{
	printf "\n"
	printf "Usage: ./perfcheck_ldap.ksh [-h][-D <admin>][-w <passwd>][-Z][-P <passwd>]\n"
	printf "\t[-K <kdbfile>][-H <host|IP>][-x][-d <delay>][-p <port>][-s]\n"
	printf "\t[-o <output_file>][-r][-m][-l <num>][-v][-V <version>]\n"
	printf "\n"
	printf "This perfcheck_ldap.ksh script gathers general ldap information.\n"
	printf "\n"
	printf "\t-h\t\tPrint usage\n"
	printf "\t-D <admin>\tAdmin DN in case anonymous binds are disabled\n"
	printf "\t-w <passwd>\tAdmin DN password\n"
	printf "\t-H <host|IP>\tPassing a specific interface to connect to\n"
	printf "\t-Z\t\tDoing an SSL connection (requires -P and -K)\n"
	printf "\t-P <passwd>\tKDB file password\n"
	printf "\t-K <file>\tFull path to the kdb file\n"
	printf "\t-x\t\tDebug flag - turns on the debugging mode of this script.\n"
	printf "\t-p <port>\tSpecify ldap server port if not default port 389\n"
	printf "\t-o <file>\tOutput file (default is /tmp/perfcheck_ldap.out).\n"
	printf "\t-V <version>\tVersion commands to run for multi-version installs\n"
	printf "\t-r\t\tEnables searching for replication status attributes\n"
	exit 0
}


# Main
DEBUG_FLAG="FALSE"

while getopts "o:D:ZP:K:w:hxd:p:vV:H:srml:" opt
do
	 case $opt in
	 D )
			AdminDn="$OPTARG"
			;;
	 w )
			AdminPw="$OPTARG"
			;;
	 Z )
			SslTrue=1
			;;
	 P )
			StashPw="$OPTARG"
			;;
	 K ) 
			KeyDb="$OPTARG"
			;;
	 H )
			Host="$OPTARG"
			;;
	 x )
			DEBUG_FLAG="TRUE"
			;;
	 o )
			OutputFile=$OPTARG
			;;
	 p ) 
			LdapPort=$OPTARG
			;;
	 V )
			LdapVersion="$OPTARG"
			;;
	 r )		
			Replication=1
			;;
	 h )
			printusage
			;;
	 * )
			exit $?
			;;
	 esac
done

if [[ "${DEBUG_FLAG}" = "TRUE" ]]; then
	set -x
fi

if [[ "${DEBUG_FLAG}" = "TRUE" ]]; then
	print "The value set for AdminDn: $AdminDn" >> ${OutputFile}
	print "The value set for AdminPw: $AdminPw" >> ${OutputFile}
	print "The value set for SslTrue: $SslTrue" >> ${OutputFile}
	print "The value set for StashPw: $StashPw" >> ${OutputFile}
	print "The value set for KeyDb: $KeyDb" >> ${OutputFile}
	print "The value set for OutputFile: $OutputFile" >> ${OutputFile}
	print "The value set for LdapPort: $LdapPort" >> ${OutputFile}
	print "The value set for Delay: $Delay" >> ${OutputFile}
	print "The value set for Host: $Host" >> ${OutputFile}
fi

# Main body of script

print "Running under process id: $$" >> ${OutputFile}
InitGlobalVars
CheckForRunningServer
GetVersionAndCommands

runonceind=0
while [ $runonceind -lt ${#runOnceArray[*]} ]
do
	if [[ ${DEBUG_FLAG} = TRUE ]]; then
	 	set -x
	fi
	
	EchoLogCmd "${runOnceArray[$runonceind]}" 
	print "" >> ${OutputFile}
	(( runonceind=runonceind+1 ))
done

if [[ -n "$RootDseCmdPwd" ]]; then
	RunCmdsWithPassword "$RootDseCmdPwd" "$RootDseCmd"
fi
