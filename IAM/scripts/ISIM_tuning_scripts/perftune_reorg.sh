#!/bin/sh

# perftune_reorg.sh
# Author: Casey Peel (cpeel@us.ibm.com)
# Last Updated: 2007/09/11 0933 MDT
# Desription:
#   Shell script to run the db2 reorg command on one or more tables
#   for a given database and schema.
# Usage:
#   This script should be run as the user for the database (ie: one that
#   has connect and reorg abilities and permissions).
#
# ./perftune_reorg.sh [DATABASE [SCHEMA [TABLES]]]
#    DATABASE = database to run against (optional - default ldapdb2)
#      SCHEMA = schema to run against (optional - default LDAPDB2)
#      TABLES = list of tables to run against, if none are given, all
#               tables are processed
#
# Note: If SCHEMA is given, DATABASE must be given. Likewise if TABLES
#   are specified, SCHEMA and DATABASE must be given.

# If the database requires authentication passed into the
# "db2 connect to DB" command, set it here
#DBAUTH="USER username USING password"
DBAUTH=

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

# Get any tables specified on the command line
if [ $# -gt 0 ]; then
  TABLES=$*
fi

# Connect to the database
echo Connecting to $DATABASE $DBAUTH
db2 connect to $DATABASE $DBAUTH

# if we failed to connect to the database, bail
if [ $? -ne 0 ]; then
  echo
  echo ERROR:
  echo Unable to connect to database $DATABASE the following databases are
  echo in the database directory for this system
  db2 list database directory | grep "Database name" | sort -u
  exit
fi

FOUND_TABLES=0
export FOUND_TABLES

# Execute reorg either on all ables or
# just the ones specified on the command line
if [ "x$TABLES" = "x" ]; then
   # Execute reorg on all tables
   echo
   echo Performing reorg on all tables for schema $SCHEMA
   for i in `db2 connect to $DATABASE $DBAUTH > /dev/null; 
      db2 "select TABNAME,TABSCHEMA from SYSSTAT.TABLES where TABSCHEMA = '$SCHEMA' order by TABNAME" |
      grep $SCHEMA | cut -d" " -f1`
   do
      echo Table: $SCHEMA.$i
      db2 reorg table $SCHEMA.$i
      db2 reorg indexes all for table $SCHEMA.$i
      FOUND_TABLES=1
   done
else
   # Execute reorg on a specific table(s)
   echo
   echo Performing reorg on tables: $TABLES for schema $SCHEMA
   for i in $TABLES
   do
      echo Table: $SCHEMA.$i
      db2 reorg table $SCHEMA.$i
      db2 reorg indexes all for table $SCHEMA.$i
      FOUND_TABLES=1
   done
fi

# If no tables were found, print some helpful information about
# getting the right schema names
if [ $FOUND_TABLES -eq 0 ]; then
  echo
  echo WARNING:
  echo No tables found, your schema \($SCHEMA\) may be incorrect.
  echo The following schemas are available:
  db2 "select distinct cast(TABSCHEMA as varchar(30)) as TABSCHEMA from SYSSTAT.TABLES"
  exit
fi

