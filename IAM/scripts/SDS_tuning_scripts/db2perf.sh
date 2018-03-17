#!/bin/sh
##############################################################################
# 
# Licensed Materials - Property of IBM
# 
# Restricted Materials of IBM
# 
# (C) COPYRIGHT IBM CORP. 2006. All Rights Reserved.
# 
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
# 
############################################################################## 
#
# Script:  db2perf.sh
#
# Author:  Michael Seedorff, IBM/Tivoli Services
#
# Description:  This script creates the necessary bindings to use the
#      REOPT command and increase performance for the DB2 database.  
# 
# Prerequisites:  
#      This script must be executed by the owner of the DB2 instance in which
#         the specified database resides.  The default database is ldapdb2.
#
# Change History:                                                      
#      2006/02/10 Version 1.0 -  Michael Seedorff, IBM/Tivoli Services 
#         Original version.                                            
#                                                                      

usage()
{
   cat <<EOF

Usage:  db2perf.sh [ -db dbname ]

Options:
	-db dbname	DB name to update with bind scripts (Default=ldapdb2)

Notes:  Must be executed as the DB2 instance owner

EOF
}

# Setup Default variable settings
DBNAME="ldapdb2"
BNDDIR="$HOME/sqllib/bnd"

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
         DBNAME=$2
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

if [ ! -d "${BNDDIR}" ]
then
   echo ""
   echo "  ERROR:  Directory ${BNDDIR} not found." 
   echo ""
   exit 59
fi

cd "${BNDDIR}"

db2 connect to "${DBNAME}"
db2 bind @db2ubind.lst BLOCKING ALL GRANT PUBLIC
db2 bind @db2cli.lst BLOCKING ALL GRANT PUBLIC
db2 bind db2schema.bnd BLOCKING ALL GRANT PUBLIC sqlerror continue
db2 bind db2clipk.bnd collection NULLIDR1
db2 bind db2clipk.bnd collection NULLIDRA

