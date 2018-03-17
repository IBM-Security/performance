#/bin/ksh
##############################################################################
# 
# Licensed Materials - Property of IBM
# 
# Restricted Materials of IBM
# 
# (C) COPYRIGHT IBM CORP. 2002, 2003, 2004, 2005, 2006. All Rights Reserved.
# 
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
# 
############################################################################## 
#
# Script:  db2_tunings.sh
#
# Author:  Richard Macbeth, IBM/Tivoli Services
#
# Description:  
#
# Prerequisites:  
#      This script must be run under the context of the DB2 instance
#         owner (ldapdb2).  It does not require write authority to the 
#         current directory.  
#
#      The LDAP Server must be stopped. This script will stop and start
#         the DB2 instance.
#
# Usage:
#      See "usage" block below or run  db2_tunings.sh -?
#
# Change History:
#      2006/08/29 Version 2.3 -  Michael Seedorff, IBM/Tivoli Services
#         Updated estimate code for AIX to report MB.  
#         Added estimate code for Linux.
#         Truncated the decimal point and 00 that from the estimate (all OSes).
#  
#      2006/04/29 Version 2.2 -  Richard Macbeth, IBM/Tivoli Services
#         Deleted INTRA_PARALLEL, DFT_DEGREE, and max_querydegree from script. 
#            LDAP uses default setting for these settings. 
#  
#         Updated comments.
#  
#      2006/03/31 Version 2.1 -  Richard Macbeth, IBM/Tivoli Services
#         Added and Change variuos settings such as: 
#            MAXAPPLS, MAXFILOP, DFT_PREFETCH_SZ, DFT_EXTENT_SZ, 
#            LOCKTIMEOUT, LOCKLIST, DBHEAP, CATALOGCACHE_SZ
#
#         Changed IOCLEANERS to IOSERVERS + 2.
#
#      2006/02/20 Version 2.0 -  Michael Seedorff, IBM/Tivoli Services
#         Added command line parameters.
#
#         Added estimation tool with ratio.
#
#      2005/04/01 Version 1.6 -  Richard Macbeth, IBM/Tivoli Services
#
#
#      2002/01/01 Version 1.0 -  Richard Macbeth, IBM/Tivoli Services
#         Original Version
#

usage()
{
   cat <<EOF

Usage:	db2_tunings.sh -s size [ -r ratio ] [ -e ] [ -db dbname ] 

	db2_tunings.sh -ibp ibmdefaultbp -lbp ldapbp [ -db dbname ] 

Options:
	-db dbname	DB name to update (Default=ldapdb2)
	-s size 	Target memory usage in MB 
	-r ratio 	Bufferpool ratio, IBMDefaultBP/LdapBP (Default=3)
	-ibp ibmdefbp	Size of ibmdefaultbp bufferpool setting 
	-lbp ldapbp	Size of ldapbp bufferpool setting 
	-e 		Estimate bufferpools only.  If size is not specified, 
			   the amount of system memory will be determined and 
			   SIZE will set to 50% of the total.  If system memory 
			   cannot be determined, size must be specified.

Notes:  Must be executed as the DB2 instance owner

EOF
}


###############
## CONSTANTS ##
###############

SHEAPTHRES=30000
DBHEAP=3000
CATALOGCACHE_SZ=64
CHNGPGS_THRESH=60
SORTHEAP=7138
MAXLOCKS=80
LOCKTIMEOUT=120
LOCKLIST=400
MINCOMMIT=1
UTIL_HEAP_SZ=5000
APPLHEAPSZ=2048
STAT_HEAP_SZ=5120
## IOCLEANERS and IOSERVERS are now calculated based on the ldapbp value
#NUM_IOCLEANERS=8
#NUM_IOSERVERS=6
DFT_PREFETCH_SZ=32
MAXFILOP=384
MAXAPPLS=100
PCKCACHESZ=1440
# If you are going to change the DFT_ENTENT_SZ you will also need to 
#    remove the comment character from the "db2 update" command later on in 
#    this script.    HINT: Search for EXTENT to find the command.
DFT_EXTENT_SZ=32

LOGFILSIZ=5000
LOGPRIMARY=5
LOGSECOND=60

# If you are going to change the NEWLOGPATH you will also need to 
#    remove the comment character from the "db2 update" command later on in 
#    this script.    HINT: Search for NEWLOGPATH to find the command.
NEWLOGPATH=/usr/logfiles/logs

######################
## END DB CONSTANTS ##
######################


# Print current db config settings 
printCfg()
{
   # Get the current db config settings
   echo ""
   echo "The DB2 configuration parameters settings are as follows:"
   echo ""
   # Put each parameter on a separate line to make it easier to read.
   db2 get database configuration for ${DBNAME} | egrep \
"BUFFPAGE|\
DBHEAP|\
CATALOGCACHE_SZ|\
CHNGPGS_THRESH|\
SORTHEAP|\
MAXLOCKS|\
LOCKTIMEOUT|\
LOCKLIST|\
MINCOMMIT|\
UTIL_HEAP_SZ|\
APPLHEAPSZ|\
STAT_HEAP_SZ|\
NUM_IOCLEANERS|\
NUM_IOSERVERS|\
DFT_PREFETCH_SZ|\
MAXFILOP|\
MAXAPPLS|\
PCKCACHESZ|\
LOGFILSIZ|\
LOGPRIMARY|\
LOGSECOND|\
DFT_EXTENT_SZ"
}

updateCfg()
{
   # Tune the db config settings
   echo ""
   echo "Updating the DB2 config settings"
   echo ""
   
   db2 update dbm cfg using SHEAPTHRES ${SHEAPTHRES}
   db2 update database configuration for ${DBNAME} using SORTHEAP ${SORTHEAP}
   db2 update database configuration for ${DBNAME} using DBHEAP ${DBHEAP}
   db2 update database configuration for ${DBNAME} using CATALOGCACHE_SZ ${CATALOGCACHE_SZ}
   db2 update database configuration for ${DBNAME} using CHNGPGS_THRESH ${CHNGPGS_THRESH}
   db2 update database configuration for ${DBNAME} using MAXLOCKS ${MAXLOCKS}
   db2 update database configuration for ${DBNAME} using LOCKTIMEOUT ${LOCKTIMEOUT}
   db2 update database configuration for ${DBNAME} using LOCKLIST ${LOCKLIST}
   db2 update database configuration for ${DBNAME} using MINCOMMIT ${MINCOMMIT}
   db2 update database configuration for ${DBNAME} using UTIL_HEAP_SZ ${UTIL_HEAP_SZ}
   db2 update database configuration for ${DBNAME} using APPLHEAPSZ ${APPLHEAPSZ}
   db2 update database configuration for ${DBNAME} using STAT_HEAP_SZ ${STAT_HEAP_SZ}
   db2 update database configuration for ${DBNAME} using NUM_IOCLEANERS ${NUM_IOCLEANERS}
   db2 update database configuration for ${DBNAME} using NUM_IOSERVERS ${NUM_IOSERVERS}
   db2 update database configuration for ${DBNAME} using DFT_PREFETCH_SZ ${DFT_PREFETCH_SZ}
   db2 update database configuration for ${DBNAME} using MAXFILOP ${MAXFILOP}
   db2 update database configuration for ${DBNAME} using MAXAPPLS ${MAXAPPLS}
   db2 update database configuration for ${DBNAME} using PCKCACHESZ ${PCKCACHESZ}
   #db2 update database configuration for ${DBNAME} using DFT_EXTENT_SZ ${DFT_EXTENT_SZ}
   db2 alter tablespace userspace1 NO FILE SYSTEM CACHING
   db2 alter tablespace LDAPSPACE NO FILE SYSTEM CACHING
}

suggestions()
{
   UNAME=`uname`

   echo ""
   if [ -z "${SIZE}" ]
   then
      case ${UNAME} in
         SunOS)
            REALMEM=`/usr/sbin/prtconf | grep "Memory size:" | awk '{print $3}'`
            ;;
         AIX)
            REALMEM=`lsattr -El sys0 | grep "^realmem"  | awk '{ print $2 }'`
            REALMEM=`echo "${REALMEM}/1024" | bc`
            ;;
         Linux)
            REALMEM=`free | grep "^Mem"  | awk '{ print $2 }'`
            REALMEM=`echo "${REALMEM}/1024" | bc`
            ;;
         *)
            echo "Unable to determine the amount of memory on your OS."
            ;;
      esac
   fi
   
   if [ ! -z "${REALMEM}" ]
   then
      SIZE=`echo "scale = 4; ${REALMEM}*0.50" | bc | cut -d\. -f1`
      echo "Memory Detected: ${REALMEM} MB"
      echo "Recommended Memory Size: ${SIZE} MB  (assumes 50% of total memory)"
   else
      if [ -z "${SIZE}" ]
      then
         usage
	 exit 26
      else
         echo "Estimated Memory Size: ${SIZE} MB  (User specified)"
      fi
   fi
   GUESSLBP=`echo "scale = 4; ${SIZE}*32/(1+${RATIO})" | bc | cut -d\. -f1`
   GUESSIBP=`echo "scale = 4; ${GUESSLBP}*8*${RATIO}" | bc | cut -d\. -f1`

   echo "Recommended ibmdefaultbp setting: ${GUESSIBP}  (assumes RATIO=${RATIO})"
   echo "Recommended ldapbp setting: ${GUESSLBP}  (assumes RATIO=${RATIO})"
   echo ""
}

checkrc()
{
   if [ ! "$RC" -eq "0" ]
   then
      echo "Command Failed!  Exiting."
      exit 45
   fi
}

checkDB2rc()
{
   if [ ! "$RC" -lt "4" ]
   then
      echo "DB2 Command Failed!  Exiting."
      exit 45
   fi
}

# BEGIN main section of code

# Setup Default variable settings
LOGDIR=/tmp
LOGFILE=db2_tunings.log
MYLOG="${LOGDIR}/${LOGFILE}"
TEECMD="tee -a ${MYLOG}"

RATIO=3
DBNAME=ldapdb2

PARMS=0
IPARM=1
LPARM=2
RPARM=4
SPARM=8
EPARM=32

# Backup up the log file before starting
if [ -f "${MYLOG}" ]
then
   mv "${MYLOG}" "${MYLOG}.bak" 
fi

if [ `uname` = "SunOS" ];then
   AWK=nawk
else
   AWK=awk
fi

# Check command line parameters
while [ $# -gt 0 ]
do 
   case $1 in
      -db)
         if [ "x$2" = "x" ]
         then
            usage
            exit 25
         fi
         DBNAME=$2
         shift
         shift
         ;;
      -r)
         if [ "x$2" = "x" ]
         then
            usage
            exit 25
         fi
	 # Ensure that the value provided is strictly numeric, allowing for
	 #   one decimal point
         echo $2 | egrep "^[0-9]*$|^[0-9]*\.[0-9]*$" > /dev/null
	 if [ "$?" != "0" ]
         then
            echo "ERROR:  Ratio specified is not a numeric value - $2."
            exit 68
         fi
         RATIO=$2
	 if [ "${RATIO}" = "0" ]
         then
            echo "ERROR:  Ratio cannot be 0."
            exit 68
         fi
	 PARMS=`expr ${PARMS} + ${RPARM}`
         shift
         shift
         ;;
      -s)
         if [ "x$2" = "x" ]
         then
            usage
            exit 25
         fi
	 # Ensure that the value provided is strictly numeric, allowing for
	 #   one decimal point
         echo $2 | egrep "^[0-9]*$|^[0-9]*\.[0-9]*$" > /dev/null
	 if [ "$?" != "0" ]
         then
            echo "ERROR:  Size specified is not a numeric value - $2."
            exit 68
         fi
         SIZE=$2
	 if [ "${SIZE}" = "0" ]
         then
            echo "ERROR:  Size cannot be 0."
            exit 68
         fi
	 PARMS=`expr ${PARMS} + ${SPARM}`
         shift
         shift
         ;;
      -ibp)
         if [ "x$2" = "x" ]
         then
            usage
            exit 25
         fi
	 # Ensure that the value provided is strictly an integer
         echo $2 | egrep "^[0-9]*$" > /dev/null
	 if [ "$?" != "0" ]
         then
            echo "ERROR:  Size of IBMDefaultBP specified is not an integer - $2."
            exit 68
         fi
         IBMDEFBP=$2
	 if [ "${IBMDEFBP}" = "0" ]
         then
            echo "ERROR:  IBMDefaultBP cannot be 0."
            exit 68
         fi
	 PARMS=`expr ${PARMS} + ${IPARM}`
         shift
         shift
         ;;
      -lbp)
         if [ "x$2" = "x" ]
         then
            usage
            exit 25
         fi
	 # Ensure that the value provided is strictly an integer
         echo $2 | egrep "^[0-9]*$" > /dev/null
	 if [ "$?" != "0" ]
         then
            echo "ERROR:  Size of LdapBP specified is not an integer - $2."
            exit 68
         fi
         LDAPBP=$2
	 if [ "${LDAPBP}" = "0" ]
         then
            echo "ERROR:  LdapBP cannot be 0."
            exit 68
         fi
	 PARMS=`expr ${PARMS} + ${LPARM}`
         shift
         shift
         ;;
      -\?)
         usage
         exit 25
         ;;
      --help)
         usage
         exit 25
         ;;
      -e)
	 PARMS=`expr ${PARMS} + ${EPARM}`
         shift
         ;;
      *)
         echo "Invalid parameter - \"$1\""
         usage
         exit 56
            ;;
   esac
done

# Verify that the correct command line parameters were specified.  The valid 
# required parameters are as follows:
#    -i and -l must be specified together (PARMS=3); no -s or -r
#       or
#    -s must be specified (PARMS=8); no -i or -l; -r is optional
echo ${PARMS} | egrep "^3$|^8$|^12$|^32$|^36$|^40$|^44$" > /dev/null
if [ "$?" != "0" ]
then
   usage
   exit 25
fi

if [ "${PARMS}" -gt "31" ]
then
   suggestions
   exit 25
fi

# Ensure that DB2 has been started
db2start 2>&1 > ${MYLOG}

### DB2 buffer pool tuning

# Connect to the DB
db2 connect to ${DBNAME} 
RC=$?
checkDB2rc

# Get the current buffer pool settings
echo ""
echo "The current buffer pool settings are as follows:"
echo ""
db2 "select bpname,npages,pagesize from syscat.bufferpools"

# Tune the buffer pool

echo ""
echo "Updating the buffer pool settings."
echo ""

# 
# IBMDEFBP = bufferpools for ibmdefaultbp
# LDAPBP = bufferpools for ldapbp
#
# If IBMDEFBP and LDAPBP have been specified on the command line, then
# those values will be used as is.  If SIZE was specified, then the 
# appropriate bufferpool values must be calculated. 
#
# Numbers Explained:
#    SIZE is the total amount of memory that should be used (in MB), in this 
#    case.
#
#    MEM is the total amount of memory (in bytes) that the combined bufferpools 
#    should use.  MEM=SIZE*1024*1024.
#
#    RATIO is the comparison between the sizes (in bytes) of IBMDefaultBP and 
#    LdapBP, however, keep in  mind that the pagesize of LdapBP (32k) is 8 
#    times larger than IBMDefaultBP (4k).  
#
#    The memory will be divided based on RATIO.  IBMDefaultBP will get RATIO
#    times as much space as LdapBP.  For RATIO=3, LdapBP will be allocated
#    X amount of space and IBMDefaultBP will be allocated 3X amount of space.
#
#       MEM =  SIZE * 1024 *1024
#       MEM = (LDAPBP*PAGESIZE32k) + (IBMDEFBP*PAGESIZE4k)
#       PAGESIZE32k = PAGESIZE4k*8
#       PAGESIZE4k = 4096
#       
#       IBMDEFBP * PAGESIZE4k = RATIO * LDAPBP * PAGESIZE32k
#       IBMDEFBP * PAGESIZE4k = RATIO * LDAPBP * PAGESIZE4k * 8
#       IBMDEFBP = RATIO * LDAPBP * 8
#
#       MEM = (LDAPBP*PAGESIZE32k) + (IBMDEFBP*PAGESIZE4k)
#       SIZE * 1024 * 1024 = (LDAPBP * PAGESIZE4k * 8) + (IBMDEFBP * PAGESIZE4k)
#       SIZE * 1024 * 1024 / PAGESIZE4k = (LDAPBP * 8) + RATIO * LDAPBP * 8
#       SIZE * 1024 * 1024 / 4096 / 8 = LDAPBP + RATIO * LDAPBP 
#       SIZE * 32 = LDAPBP + RATIO * LDAPBP 
#       SIZE * 32 = LDAPBP * (1 + RATIO)
#       LDAPBP = SIZE * 32 / (1 + RATIO)
#       IBMDEFBP = RATIO * LDAPBP * 8
#

if [ -z "${LDAPBP}" -a -z "${IBMDEFBP}" ]
then
   LDAPBP=`echo "scale = 4; ${SIZE}*32/(1+${RATIO})" | bc | cut -d\. -f1`
   IBMDEFBP=`echo "scale = 4; ${LDAPBP}*8*${RATIO}" | bc | cut -d\. -f1`
fi

db2 alter bufferpool ibmdefaultbp size ${IBMDEFBP}
db2 alter bufferpool ldapbp size ${LDAPBP}

### General DB configuration parameter tuning

# Calculate NUM_IOCLEANERS and NUM_IOSERVERS based on the bufferpool values.
# NUM_IOSERVERS should be set to approximately 1 for every 1500 LDAPBP.
# NUM_IOCLEANERS should be 2 higher than NUM_IOSERVERS.
NUM_IOSERVERS=`expr ${LDAPBP} / 1500`
if [ ! "${NUM_IOSERVERS}" -gt 0 ]
then
   NUM_IOSERVERS=1
fi
NUM_IOCLEANERS=`expr ${NUM_IOSERVERS} + 2`

# Print current db config settings 
printCfg 

# Update db config settings 
updateCfg 

# Print new db config settings 
printCfg 

db2 terminate
db2 force applications all
sleep 1
db2stop
db2start

# Verify new settings

db2 connect to ${DBNAME}
RC=$?
checkDB2rc
echo ""
echo "The new buffer pool settings are as follows:"
echo ""
db2 "select bpname,npages,pagesize from syscat.bufferpools"
db2 terminate


### DB2 transaction log tuning

# DB2 transaction log space is defined by the LOGFILSIZ, LOGPRIMARY, LOGSECOND,
# and NEWLOGPATH parameters.  These parameters should be tuned to allow the 
# transaction log to grow to its maximum required size.  In the normal use of 
# the IBM Directory Server, the transaction log requirements are small.  Tools
# that improve the performance of populating the directory server with a large 
# number of users typically increase the transaction log requirements.  Here 
# are examples:
#
# - The bulkload tools loads attribute tables for many entries in a single 
#   load command. One table of particular interest is the group membership 
#   table.  Bulkloading a large group of millions of users will increase the 
#   transaction log requirements.
#
#   The transaction log requirements to load a 3 million user group is 
#   around 300 MB.
#   
# - The Access Manager tuning guide scripts can update the ACL on a suffix such 
#   that the ACL must be propagated to many other entries in the directory.  
#   The IBM directory server combines all of the propagated updates into a 
#   single committed transaction.
#
#   The transaction log requirements to propagate ACLs to a suffix with
#   3 million Access Manager users is around 1.2 GB.
#
# Using the 1.2 GB requirement above, the transaction log requirements are 
# approximately
#
# 1200000000 bytes / 3000000 users = 400 bytes per user
# 
# The DB2 defaults define a single transaction log buffer to be 2000 blocks of 
# 4KB in size or 8000 KB.  The tunings in this file change this default to 5000
# blocks or approximately 20 MB.
#
# The default number of primary log files is 3 and secondary log files is 2.  
# This script sets the number primary log files to the default of 3 and adjusts 
# the number of secondary log files as described below.
#
# With the settings made by this script, the primary log can grow to a maximum 
# of (20MB * 3) or 60 MB.
#
# Instead of adjusting the number of primary logs to allow for additional 
# growth, it is better to adjust the number of secondary logs, since the 
# secondary log space is recovered when db2 is stopped and restarted 
# (db2stop/db2start).
#
# Using the 400 bytes per user requirements from the ACL propagace case and 
# the number of primary logs and size of the log file set by this script, the 
# formula for increasing the transaction log secondary buffers is as follows:
#
# ( ( <num AM users> * 400 ) - 
#           ( 20MB buffer size * 3 primary buffers ) ) / 20 MB buffer size
#
# For 3 million users, this approximates to the following:
#
# ( ( 3000000 * 400 ) - ( 20000000 * 3  ) ) / 20000000 = 57 secondary buffers
#
# The disk space requirements for this number of buffers is 1.2 MB
#           20MB * ( 3 + 57 ) = 1.2 GB
#
# We are going to use 5000 file size 5 primary 60 secondary for 1.3 GB.  We
# have 30 GB space for this.

echo ""
echo "Defining the transaction log size parameters to allow for the worst case of ACL"
echo "propagation.  The chosen setting will allow ACLs to propagate from a suffix to"
echo "up to 3 million users.  This setting can use up to 1.3GB"
echo "additional disk space in the DB2 instance owner home directory."
echo ""
echo "The number of log file size will be increased to 5000."
echo "The number of primary log buffers will be increased to 5."
echo "The number of secondary log buffers will be increased to 60."
echo ""
echo "Adjust this setting (LOGSECOND) for more or less users.  Ensure the disk space"
echo "is available for whatever setting is used, since running out of disk space"
echo "for the transaction log can corrupt the database and require reloading of the"
echo "database."
echo ""

# Get the current settings
echo "The current transaction log settings are as follows:"
echo ""
db2 get database configuration for ${DBNAME} | egrep \
   'LOGFILSIZ|LOGPRIMARY|LOGSECOND|NEWLOGPATH|Path to log files'

echo ""
echo "Updating the transaction log settings."
echo ""
db2 update database configuration for ${DBNAME} using LOGFILSIZ ${LOGFILSIZ}
db2 update database configuration for ${DBNAME} using LOGPRIMARY ${LOGPRIMARY}

# Note: Update this parameter to increase or decrease the transaction log space.
db2 update database configuration for ${DBNAME} using LOGSECOND ${LOGSECOND}

# Note: You should move the default location of the path of the log files
# By default it is put where the db2 instance is found, for example 
# /usr/opt/db2/log/LDAPDB2.  It is best if you move the location to another
# directory, preferably on a different physical drive if possible. 
#db2 update db cfg for ${DBNAME} using NEWLOGPATH "${NEWLOGPATH}" 

# Restart db2 for changes to take effect
db2stop
db2start

echo ""
echo "The new transaction log settings are as follows:"
echo ""
db2 get database configuration for ${DBNAME} | egrep \
   'LOGFILSIZ|LOGPRIMARY|LOGSECOND|NEWLOGPATH|Path to log files'

echo ""
echo "Verifying that the file system for the transaction logs is large enough to"
echo "accomodate the maximum growth."
echo ""

logfilpath=`db2 get db cfg for ${DBNAME} | grep "Path to log files" | $AWK '{print $NF}'`
fs_check=`df -k $logfilpath | $AWK 'BEGIN{getline}{print $0}'`
if [ `uname -s` = Linux ]
then
   avail=`echo $fs_check | $AWK '{print $4}'`
elif [ `uname -s` = SunOS ]
then
   avail=`echo $fs_check | $AWK '{print $4}'`
else
   avail=`echo $fs_check | $AWK '{print $3}'`
fi

logfilsiz=`db2 get database configuration for ${DBNAME} | grep LOGFILSIZ | $AWK '{print $NF}'`
logprimary=`db2 get database configuration for ${DBNAME} | grep LOGPRIMARY | $AWK '{print $NF}'`
logsecond=`db2 get database configuration for ${DBNAME} | grep LOGSECOND | $AWK '{print $NF}'`
logspace=$(( logfilsiz * 4096 * ( logprimary + logsecond ) / 1024 ))
echo "logfilsiz=$logfilsiz logprimary=$logprimary logsecond=$logsecond logspace=$logspace"

echo "The available file space on $logfilpath is $avail KB."
echo "The log parameters allow the log files to grow to a maximum of $logspace KB."
echo ""

if [ $avail -lt $logspace ];then
	echo "Warning: The maximum allowed log space exceeds the available log space."
	echo "Consider increasing the storage in the file system or decreasing the"
	echo "log space parameters."
else
	echo "Check succeeded:  There is sufficient disk space to allow for the maximum log"
	echo "file growth."
fi
echo ""

