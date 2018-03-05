#!/bin/sh

# perfcheck_database.sh
# Author: Casey Peel (cpeel@us.ibm.com)
# Last Updated: 2005/06/07 15:42 CST
# Desription:
#   Shell script to gather tuning information for a database.
# Usage:
#   This script should be run as the user for the database. Output can
#   be redirected to a file to send to support if needed.
#
#   The only argument to this file is the name of the database to check.


# Name of the database
DATABASE=$1

# Stop if we are root
ID=`id | grep uid=0`
if [ "$?" != "1" ]
then
echo "ERROR: This script should be run as the database owner."
exit 1;
fi

# Stop if we didn't give a database name
if [ "$DATABASE" = "" ]
then
echo "ERROR: You must specify a database on the command line."
echo "Usage: $0 <database_name>"
exit 1;
fi


echo "*******************************"
echo "perfcheck_database.sh"
uname -a
date
echo "*******************************"

echo
echo "Environment Settings"
echo "---------------------------"
db2set -all

echo
echo "DBM Settings"
echo "---------------------------"
for i in DFT_MON SHEAPTHRES; do db2 get dbm cfg | grep $i; done

echo
echo "Database settings"
echo "---------------------------"
for i in "HEAP)" APPLHEAPSZ APP_CTL_HEAP_SZ MAXLOCKS "MAXAPPLS)" AVG_APPLS MAXFILOP LOGFILSIZ LOGPRIMARY LOGSECOND MINCOMMIT; do db2 get db cfg for $DATABASE | grep $i; done


echo
echo "Bufferpools"
echo "---------------------------"
db2 connect to $DATABASE > /dev/null 2>&1
db2 "select cast(bpname as varchar(25)) as BPNAME,npages,pagesize from syscat.bufferpools"

echo
echo "Tablespace"
echo "---------------------------"
db2 list tablespaces show detail

echo
echo "Indexes"
echo "---------------------------"
db2look -d $DATABASE -a -e 2> /dev/null | grep "CREATE INDEX"

