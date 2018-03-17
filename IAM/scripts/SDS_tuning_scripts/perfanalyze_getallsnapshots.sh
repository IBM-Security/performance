#!/bin/sh

# perfanalyze_getallsnapshots.sh
#
# Last UpdateD: 2003/10/31 1713 CST
# Desription:
#   Shell script to get all of the snapshots for a database
# Usage:
#   This script should be run as the user for the database (ie: one that
#   has snapshot privileges).
#      ./perfanalyze_getallsnapshots.sh <db_name>
#
# For example if you database name was ldapdb2 do the follwoing:
#
# ./perfanalyze_getallsnapshots.sh ldapdb2 

DATE=`date +%Y%m%d-%H%M`
DATABASE=$1

echo "Connecting to $DATABASE"
db2 connect to $DATABASE

echo "Getting snapshots on:"
for i in database tables locks bufferpools
do
echo SNAPSHOT: $i
db2 get snapshot for $i on $DATABASE > /tmp/snapshot-$i.$DATE
done

echo SNAPSHOT: dynamic sql
db2 get snapshot for dynamic sql on $DATABASE > /tmp/snapshot-dynamicsql.$DATE

