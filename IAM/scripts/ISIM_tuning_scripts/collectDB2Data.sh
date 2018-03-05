#!/bin/sh

# collectDB2Data.sh
# Author: Casey Peel (cpeel@us.ibm.com)
# Revision: Nnaemeka Emejulu (eemejulu@us.ibm.com)
# Revision: Lidor Goren (lidor@us.ibm.com)
# Last Updated: 2014/12/12
# Description:
#    This script will collect various information from the specified DB2
#    database to determine if all of the desired tunings have been
#    applied.
#
#    This script should be run as the database administrator and have
#    write permission to the current working directory (or TEMP should
#    be updated to a directory with write permissions).
# Usage:
#    ./collectDB2Data.sh database [USER username USING password]
####Latest ADDITIONS####
#Date: 2013/12/12
#Modified default shell from bash to sh
#######
#Date: 2014/12/09
#Modifed text comparison to verify successful fetch of schema from db2look
#######
#######
#Author: Lidor Goren (lidor@us.ibm.com)
#Date: 2014/12/12
#- Created check_number_of_records which checks the number of records retrieved in a DB2 SELECT command
#  This command is used in lieu of the more generic check_file_contents to ascertain DB2 SELECT results
#- Added code to rename 'db2data' subdirectory if it exists, so new data can be written
#- Redirected errors and warnings to stderr
#######


# Directory to store collected information - this directory must be writeable
TEMP=.
export TEMP

#----------------------------------------------------------------------

# DATA must not be modified. Update TEMP if you wish to put the contents
# in a different directory
DATA=$TEMP/db2Data
export DATA

# detect the OS and do some OS-specific modifications
OS=`uname`
GREP=grep
if [ "$OS" == "SunOS" ]; then
   GREP=/usr/xpg4/bin/grep
fi

# set up some functions
function check_file_contents {
   FILE=$1
   STRING=$2
   #STRING=$3

   $GREP -q "$STRING" $FILE
   if [ $? -ne 0 ]; then
      >&2 echo WARNING: File $FILE may not have desired contents!
      return 1
   fi

   return 0
}

function check_number_of_records {
   FILE=$1
   N=$(sed -n 's/^ *\([0-9][0-9]*\) record.* selected.*$/\1/p' $FILE)
   if [ $N -le 0 ]; then
      >&2 echo WARNING: File $FILE contains no records!
      return 1
   fi
   return 0
}

#----------------------------------------------------------------------

# Detect argument DATABASE if it is passed into the script
if [ $# -gt 0 ]; then
   DATABASE=$1
   shift
fi

if [ $# -gt 0 ]; then
   DBAUTH=$*
fi

if [ "$DATABASE" == "" ]; then
   >&2 echo ERROR: No database specified.
   exit 1
fi

echo "Connecting to $DATABASE $DBAUTH"
db2 connect to $DATABASE $DBAUTH

# if we failed to connect to the database, discontinue 
if [ $? -ne 0 ]; then
   >&2 echo
   >&2 echo ERROR:
   >&2 echo Unable to connect to database $DATABASE the following databases are
   >&2 echo in the database directory for this system
   >&2 db2 list database directory | $GREP "Database name" | sort -u
   >&2 echo 
   >&2 echo You may need to specify authentication information, like:
   >&2 echo $0 $DATABASE USER username USING password
   exit 1
fi

# check to make sure the temp directory does not already exist
if [ -d $DATA ]; then
   OLDDATA="$DATA"
   i=1
   while [ -d $OLDDATA ]; do
     OLDDATA="$DATA$i"
     i=$((i+1))
   done
   mv $DATA $OLDDATA
   >&2 echo Older storage directory "($DATA)" renamed to "($OLDDATA)".
fi
echo "Creating storage directory $DATA"
mkdir -p $DATA
if [ ! -d $DATA ]; then
   >&2 echo ERROR: Unable to create data directory "($DATA)".
   exit 1
fi

# now start collecting data

echo "Storing the OS type"
echo $OS > $DATA/os.name

echo "Storing the name of the database"
echo $DATABASE > $DATA/db.name

echo "Getting the database level"
db2level > $DATA/db2level.out
check_file_contents $DATA/db2level.out "DB21085I"

echo "Getting the db2 env data"
db2set > $DATA/db2set.out

echo "Getting dbm config"
db2 get dbm cfg > $DATA/dbm.cfg
check_file_contents $DATA/dbm.cfg "Database Manager Configuration"

echo "Getting db config"
db2 get db cfg for $DATABASE show detail > $DATA/db.cfg
check_file_contents $DATA/db.cfg "Database Configuration"

echo "Getting bufferpool information"
db2 "select bpname,npages,pagesize from syscat.bufferpools" > $DATA/bufferpools.out
check_file_contents $DATA/bufferpools.out IBMDEFAULTBP

echo "Getting statistics information"
db2 "select tabschema,tabname,card from sysstat.tables order by card" > $DATA/cardinalities.out
check_number_of_records $DATA/cardinalities.out
db2 "select tabschema,tabname,stats_time from syscat.tables order by stats_time" > $DATA/runstats_times.out
check_number_of_records $DATA/runstats_times.out

echo "Getting composite snapshot"
db2 get snapshot for all on $DATABASE > $DATA/snapshot.out
check_file_contents $DATA/snapshot.out "Database Snapshot"

echo "Getting table definitions"
db2look -d $DATABASE -e > $DATA/tables.ddl
check_file_contents $DATA/tables.ddl "DDL Statements for Table"
if [ $? -eq 1 ]; then
   # see if this is an ITDS database
   ROW=`$GREP LDAP_ENTRY $DATA/cardinalities.out`
   #ROW=`$GREP LDAP_ENTRY $DATA/snapshot.out`
   if [ $? -eq 0 ]; then
      USER=`echo $ROW | cut -d' ' -f1`
   fi

   # try the ITIM database
   ROW=`$GREP PROCESSDATA $DATA/cardinalities.out`
   #ROW=`$GREP "Authorization ID" $DATA/snapshot.out`
   if [ $? -eq 0 ]; then
      USER=`echo $ROW | cut -d' ' -f1`
      #echo $ROW | cut -d' ' -f5
   fi

   if [ "$USER" != "" ]; then
      echo Trying again with USER=$USER

      db2look -d $DATABASE -u $USER -e > $DATA/tables.ddl
      check_file_contents $DATA/tables.ddl "DDL Statements for Table"

      if [ $? -eq 1 ]; then
         >&2 echo ERROR: Unable to get table definition.
         >&2 echo SUGGESTION: Set USER to the database owner, export USER, and try again.
      fi
   fi
fi

# finished collecting data, package it up

echo "tar'ing up contents"
PWD=`pwd`
cd $TEMP
tar cf ${DATABASE}_db2Data.tar db2Data
if [ $? -eq 0 ]; then
   # sanity check that $DATA is a valid directory before wiping it
   if [ -d $DATA -a "$DATA" != "/" ]; then
      echo "Removing temporary directory"
      rm $DATA/*
      rmdir $DATA
   else
      >&2 echo "WARNING: Leaving temporary directory ($DATA) as there was some uncertainty about removing it."
   fi

   echo
   echo "Data resides in file $TEMP/${DATABASE}_db2Data.tar"
else
   >&2 echo "WARNING: Unable to tar up the $TEMP/db2Data directory. Directory and contents will be left as-is."
   >&2 echo
   >&2 echo "Data resides in directory $TEMP/db2Data"
fi
cd $PWD

# vim: sw=3 ts=3 expandtab
