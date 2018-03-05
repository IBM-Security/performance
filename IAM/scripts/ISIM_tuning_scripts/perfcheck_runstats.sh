#!/bin/sh

# perfcheck_runstats.sh
# Author: Casey Peel (cpeel@us.ibm.com)
# Last Updated: 2008/07/23 1056 MDT
# Desription:
#   Shell script to check the db2 runstats a given database.
# Usage:
#   This script should be run as the user for the database.

DATABASE=$1

SCHEMA=SYSSTAT

# Connect to the database
echo Connecting to $DATABASE
db2 connect to $DATABASE

echo Last time Runstats was run for tables:
db2 "select cast(tabschema as varchar(20)) as TABSCHEMA, cast(tabname as varchar(35)) as TABNAME, stats_time from syscat.tables order by tabname"

echo Last time Runstats was run for indexes:
db2 "select cast(tabschema as varchar(20)) as TABSCHEMA, cast(tabname as varchar(35)) as TABNAME, stats_time from syscat.indexes order by tabname"

echo Specialized statistics:
db2 "select cast(tabname as varchar(20)) as TABNAME, card from sysstat.tables where card >= 9E10"

# Get statistics on various tables
echo Getting statistics on COLDIST COLUMNS INDEXES TABLES
for i in COLDIST COLUMNS INDEXES TABLES
do
echo Table: $SCHEMA.$i
db2 "select * from $SCHEMA.$i"
done
