#!/bin/ksh
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
# Script:  tune_runstats.sh
#
# Base on an orig script unknown Author
# Author:  Richard Macbeth, IBM/Tivoli Services
#
# Description:  This script runs the db2 runstats command on one or more 
#      tables for a given database and schema. It autodetects the db2 version 
#      using db2level and passes the appropriate string to runstats to 
#      allow writes to occur during the runstats.
#
# Prerequisites:  
#      Run this command as the user for the database (ie: one that
#      has connect and runstats abilities and permissions).
#
# Change History:  
#      2005/10/16 Version 3.2 -  Michael Seedorff
#         Changed the command line parameters to use -db database
#         and -s schema.  The position of parameters is now irrelevant,
#         which makes it easier to add parameters in the future.
#
#         Added usage statement.
#
#      2005/10/16 Version 3.1 -  Richard Macbeth 
#         After further testing we found that it is best to add the 
#         card change for ldap_desc for use with ITIM and TAM searches
#
#      2005/??/?? Version 3.0 -  Richard Macbeth 
#         Clean up script and removed remarked sections out
#
#      2005/05/05 Version 2.8 -  Richard Macbeth 
#         Remarked out all card changes since they are not needed when 
#         you have applied FixPack 9 to DB2 8.1 making it 8.2.2 The only 
#         thing this script does now is runstats and a reorgchk on current 
#         stats at the end.  Unremark them if you are not using DB2 8.2.2.
#
#         Changed out db2 command to gather all the tables except REPLCHANGE 
#         this table should not have runstats run against it because most of 
#         the time this table is empty and the optimation will not be correct 
#         if runstats is run against it.
#
#      2005/04/03 Version 2.6 -  Richard Macbeth 
#         Changed the options for runstats from
#         OPTIONS="with distribution and sampled detailed indexes all"  
#         to running OPTIONS="and sampled detailed indexes all".
#
#         Changed the script and added the reorgchk function at the end  
#         and changed the options for that also.  It used to say:
#         OPTIONS="update statistics on table all" and now its says:
#         OPTIONS2="current statistics on table all" this way it will not run a
#         runstats when it runs the reorgchk. this part now only take a few  
#         seconds to generate the reorgchk.out file for someone to look at it.
#         Also change OPTIONS to OPTIONS2 so it will have a unique value in 
#         this script since runstats portion uses the same varable.
#
#      2004/11/24 Version 2.0 -  Richard Macbeth 
#         Deleted the card chage to the ldap_entry table to fix the 
#         modifyTimeStamp query now query is sub second
#
#      2002/01/01 Version 1.1 -  Richard Macbeth 
#         Original updated Version from unknown author
#

usage()
{
   SCRIPT=tune_runstats.sh
   cat <<EOF

Usage:  $SCRIPT [ -db dbname ] [ -s schema ] 

Options:
	-db dbname	Database name (Default=ldapdb2)
	-s  schema	Schema name (Default=LDAPDB2)
	-?	Prints usage statement
	--help	Prints usage statement

EOF
}

umask 022


# Check for optional variables.  Set defaults as required and create 
#    directories/backup files as necessary.
if [ -z "${LOGDIR}" ]
then
   LOGDIR=/tmp
else
   if [ ! -d "${LOGDIR}" ]
   then
      echo "LOGDIR does not exist.  Creating ${LOGDIR}."
      mkdir -p ${LOGDIR} 
   fi
fi

if [ -z "${LOGFILE}" ]
then
   LOGFILE=tune_runstats.log
fi

# Backup up the log file before starting
if [ -f "${LOGDIR}/${LOGFILE}" ]
then
   mv "${LOGDIR}/${LOGFILE}" "${LOGDIR}/${LOGFILE}.bak" 
fi

# Setup Default variable settings
DATABASE=ldapdb2
SCHEMA=LDAPDB2
TEECMD="tee -a ${LOGDIR}/${LOGFILE}"

# Default options for runstats command
# Find out DB2 version for runstats syntax
if db2level | grep "DB2 v7" > /dev/null; then
   ACCESS="shrlevel change"
   OPTIONS="WITH DISTRIBUTION AND SAMPLED DETAILED INDEXES ALL"
   echo "Detected DB2 major version 7"
elif db2level | grep "DB2 v8" > /dev/null; then
   ACCESS="allow write access"
   OPTIONS="WITH DISTRIBUTION ON ALL COLUMNS AND SAMPLED DETAILED INDEXES ALL"
   echo "Detected DB2 major version 8"
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
         DATABASE=$2
         shift
         shift
         ;;
      -s)
         if [ "x$2" = "x" ]
         then
            usage
            exit 25
         fi
         SCHEMA=`echo $2 | tr 'a-z' 'A-Z'`
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
      *)
         echo "Invalid parameter - \"$1\""
         usage
         exit 56
         ;;
   esac
done

# Check for required variables 

# This is a template for verifying that a required option was set on the cmd line
#if [ -z "${REQVARIABLE}" ]
#then
#   echo "ERROR:  Variable REQVARIABLE must be defined."
#   exit 65
#fi


date

# Connect to the database
echo "Connecting to $DATABASE"
db2 connect to $DATABASE

# Execute runstats on all tables
echo "Performing runstats on all tables for schema $SCHEMA"
echo "   with options: $OPTIONS $ACCESS"
for i in `db2 connect to $DATABASE > /dev/null; db2 -x "select rtrim(tabschema) concat '.' concat rtrim(tabname) from syscat.tables where type ='T' and tabname not in('REPLCHANGE')"`
do
   echo "Table: $i"
   db2 runstats on table $i $OPTIONS $ACCESS
   date
done

# Since this is an LDAP database, update LDAP_DESC and LDAP_ENTRY 
# stats in the statistics table - remark these out if you are having 
# problems after you are running with or on DB2 8.2.2(this is 8.1  
# with fixpack 9 and above with reopt=3 statement.  
# Only unremark LDAP_ENTRY if you really need to after full testing.
 
# if [ "$SCHEMA" = "LDAPDB2" ]; then
echo "Updating LDAP_DESC and LDAP_ENTRY stats in the statistics table"
db2 "update sysstat.tables set card = 9E18 where tabname = 'LDAP_DESC'"
#db2 "update sysstat.tables set card = 9E18 where tabname = 'LDAP_ENTRY'"
# fi

# Now we are going to run a reorgchk and put an output file in the log  
# directory called reorgchk.out.  This can be looked at to determin if a 
# reorg of a table or index is needed.  If a reorg is needed you will 
# need to bring down the server to do the reorg and then after a reorg 
# is done you will have to re-run this script before starting ldapback 
# up again.

# Options for reorgchk command
OPTIONS2="current statistics on table all"

# Redirected Output of the reorgchk
#OUTPUT="${LOGDIR}/reorgchk.out"
OUTPUT="${LOGDIR}/${LOGFILE}"

# Connect to the database
echo "Connecting to $DATABASE"
db2 connect to $DATABASE

# Execute reorgchk on all tables or just the ones specified on the command line
echo "Performing reorgchk on Database: $DATABASE for schema $SCHEMA"
echo "  with options: $OPTIONS2 and sending it's output to $OUTPUT"
db2 reorgchk $OPTIONS2 > $OUTPUT
db2 terminate
date

