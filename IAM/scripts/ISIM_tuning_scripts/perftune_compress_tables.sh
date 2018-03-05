#!/bin/sh

# perftune_compress_tables.sh
# Author: Casey Peel (cpeel@us.ibm.com)
# Last Updated: 2008/06/11 1724 MDT
# Desription:
#   Shell script to compress specific ITDS and ITIM DB tables.
# Usage:
#   This script should be run as the user for the database.
#
# ./perftune_compress_tables.sh DBTYPE [DATABASE [SCHEMA]]
#      DBTYPE = database type: ITDS or ITIM
#    DATABASE = database to run against (optional - default ldapdb2)
#      SCHEMA = schema to run against (optional - default LDAPDB2)
#
# Note: If SCHEMA is given, DATABASE must be given.

# If the database requires authentication passed into the
# "db2 connect to DB" command, set it here
#DBAUTH="USER username USING password"
DBAUTH=

# get the selected database type
if [ $# -gt 0 ]; then
   DBTYPE=$1
   shift
fi

if [ "$DBTYPE" = "ITDS" ]; then
   TABLES="ldap_entry objectclass erparent erservice erroles owner manager secretary"
   echo ITDS database selected
   echo   tables to be compressed: $TABLES
elif [ "$DBTYPE" = "ITIM" ]; then
   TABLES="activity process processlog audit_event audit_mgmt_provisioning audit_mgmt_target audit_mgmt_delegate"
   echo ITIM database selected
   echo   tables to be compressed: $TABLES
else
   echo Invalid DBTYPE detected \($DBTYPE\)
   echo should be one of: ITDS or ITIM
   exit
fi
export TABLES

# Detect arguments DATABASE and SCHEMA
if [ $# -gt 1 ]; then
  DATABASE=$1
  SCHEMA=$2
  shift; shift
elif [ $# -gt 0 ]; then
  DATABASE=$1
  SCHEMA=LDAPDB2
  shift
else
  DATABASE=ldapdb2
  SCHEMA=LDAPDB2
fi

# ensure that the schema is uppercase
SCHEMA=`echo $SCHEMA | tr -s '[:lower:]' '[:upper:]'`

export DATABASE DBAUTH SCHEMA

# Connect to the database
echo Connecting to $DATABASE $DBAUTH
db2 connect to $DATABASE $DBAUTH

# if we failed to connect to the database, bail
if [ $? -ne 0 ]; then
  echo
  echo ERROR:
  echo Unable to connect to database $DATABASE the following databases are
  echo in the database directory for this system
  db2 list database directory | grep "Database name"
  exit
fi

echo Compressing tables
for i in $TABLES; do
   echo Enabling compression for $SCHEMA.$i
   db2 alter table $SCHEMA.$i compress yes
   echo

   echo Reorganizing the table for $SCHEMA.$i
   echo "   Started:" `date`
   db2 reorg table $SCHEMA.$i
   echo "  Finished:" `date`
   echo
done

echo "NOTICE: You *must* run perftune_runstats.sh to update the table statistics!"
