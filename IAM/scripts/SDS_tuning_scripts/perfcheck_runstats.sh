#!/bin/sh

# perfcheck_runstats.sh
#
# Last Updated: 2012/04/03 Ben Matteson Added a check for the input parameter
# Desription:
#   Shell script to check the db2 runstats a given database.
# Usage:
#   This script should be run as the user for the database.
#
# for example if you database is named ldapdb2 then do the following:
#
# ./perfcheck_runstats.sh ldapdb2  > /tmp/perfcheck_runstats.out 2>&1 
#

DATABASE=$1

if [ -z "$DATABASE" ]; then
	echo "No database name provided. Please provide the database name."
	echo "Check 'db2 list db directory' output if not sure."
	exit 2
fi	

SCHEMA=SYSSTAT

# Connect to the database
echo Connecting to $DATABASE
db2 connect to $DATABASE

# Get statistics on various tables
echo Getting statistics on COLDIST COLGROUPS COLUMNS INDEXES TABLES
for i in COLDIST COLGROUPS COLUMNS INDEXES TABLES
do
echo Table: $SCHEMA.$i
db2 "select * from $SCHEMA.$i"
done

echo Last time Runstats was run for tables:
db2 "select cast(tabschema as varchar(20)), cast(tabname as varchar(35)), stats_time from syscat.tables order by tabname" | grep -v SYS

echo Last time Runstats was run for indexes:
db2 "select cast(tabschema as varchar(20)), cast(tabname as varchar(35)), stats_time from syscat.indexes order by tabname" | grep -v SYS

echo Specialized LDAP statistics:
db2 "select cast(tabname as varchar(20)), card from sysstat.tables where tabname='LDAP_DESC' or tabname='LDAP_ENTRY'"

