#!/bin/sh

# explainSQL.sh
# Author: Dave Bachmann (bachmann@us.ibm.com)
#         Casey Peel (cpeel@us.ibm.com)
# Last Updated: 2006/08/02 1658 CDT
# Desription:
#   Script to generate an explain plan for a SQL query
# Usage:
#   Place the SQL query you want explained in a file
#   all on one line, no trailing ';'.
#   Run this script passing the filename in as an argument.
#   The explain plan will be placed in filename.exfmt
#
#   If you are running this on a database other than the LDAP
#   database, pass in the instance and database name as well
#     ie: explainSQL.sh <database> <instance> filename.sql
#
# Important:
#   If this is the first time to run an explain for this
#   database, you'll need to import the explain tables
#   first. Locate the EXPLAIN.DDL file on your system
#   (usually at sqllib/misc/EXPLAIN.DDL) and import it
#   using the following:
#     db2 -tf EXPLAIN.DDL

# Detect arguments DATABASE and INSTANCE
if [ $# -gt 1 ]; then
  DATABASE=$1
  INSTANCE=$2
  shift; shift
else
  DATABASE=ldapdb2
  INSTANCE=ldapdb2
fi

# show them what's going on
echo Note: Using DATABASE $DATABASE and instance $INSTANCE

# connect to the database
db2 connect to $DATABASE

# put us in explain mode
db2 set current explain mode explain

# optionally try different query optimizations
#db2 SET CURRENT QUERY OPTIMIZATION = 2

# run the query
db2 -f $1

# clean up
db2 commit work
db2 connect reset
db2 terminate

# generate the query plan
db2exfmt -d $DATABASE -g TIC -e $INSTANCE -n % -s % -w -1 -# 0 -o $1.exfmt
