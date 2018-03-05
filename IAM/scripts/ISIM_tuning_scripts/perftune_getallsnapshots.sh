#!/bin/sh

# perfanalyze_getallsnapshots.sh
# Author: Casey Peel (cpeel@us.ibm.com)
# Last UpdateD: 2007/09/20 1121 MDT
# Desription:
#   Shell script to get a composite snapshot for a database
# Usage:
#   This script should be run as the user for the database (ie: one that
#   has snapshot privileges).
#      ./perfanalyze_getallsnapshots.sh <db_name>

DATE=`date +%Y%m%d-%H%M`
DATABASE=$1

echo "Connecting to $DATABASE"
db2 connect to $DATABASE

echo "Getting composite snapshot"
db2 get snapshot for all on $DATABASE > snapshot.$DATE
