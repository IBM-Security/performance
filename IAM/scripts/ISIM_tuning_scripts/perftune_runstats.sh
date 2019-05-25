#!/bin/sh

# perftune_runstats.sh
# Author: Casey Peel (cpeel@us.ibm.com)
#         Dave Bachmann (bachmann@us.ibm.com)
#         Ray Pekowski (pekowski@us.ibm.com)
#         Emeka Emejulu (eemejulu@us.ibm.com)
#         Lidor Goren (lidor@us.ibm.com)
# Last Updated: 2019/05/24
# Desription:
#   Shell script to run the db2 runstats command on one or more tables
#   for a given database and schema. It autodetects the db2 version using
#   db2level and passes the appropriate string to runstats to allow writes
#   to occur during the runstats.
# Usage:
#   This script should be run as the user for the database (ie: one that
#   has connect and runstats abilities and permissions).
#
# ./perftune_runstats.sh [DATABASE [SCHEMA [TABLES]]]
#    DATABASE = database to run against (optional - default ldapdb2)
#      SCHEMA = schema to run against (optional - default LDAPDB2)
#      TABLES = list of tables to run against, if none are given, all
#               tables are processed
#
# Note: If SCHEMA is given, DATABASE must be given. Likewise if TABLES
#   are specified, SCHEMA and DATABASE must be given.


####Latest ADDITIONS####
# Date: 2013/12/11
# Added SIBOWNER table to inflate cardinality
#######
# Date: 2014/8/29  By: Lidor Goren (lidor@us.ibm.com)
# - Added optional switch [-u <user>] that allows the specification of the IDS user (if not the same as the current user)
# - Added call to external script get_ids_instance_info.pl to obtain IDS version and other environment variables that 
#   allow us to determine when to artificially inflate cardinality for LDAP_DESC and LDAP_ENTRY table
# - Version check is automated through external script compare_versions.pl
#######
# Date: 2015/2/4  By: Lidor Goren (lidor@us.ibm.com)
# restored code to Bourne-shell compatibility (to insure /bin/sh will always work, even on Solaris)
#######
# Date 2019/04/30
#Removed DB Auth so that the user can specify table

# Absolute path to this script, e.g. /home/user/bin/foo.sh
SCRIPTDIR=`dirname $0`
SCRIPTPATH=`cd $SCRIPTDIR;pwd`

# If the database requires authentication passed into the
# "db2 connect to DB" command, set it here
#DBAUTH="USER username USING password"
#If authentication is needed, then one can set DBAUTH using environment variable.
#DBAUTH=

# Limit runstats to only run on tables with fewer than a specific number
# of rows. To run on all tables, set TABLE_SIZE_LIMIT to 0
TABLE_SIZE_LIMIT=500000

# Temporary file used during the script. It will be created and removed
# automatically by the script
TEMP_FILE=/tmp/perftune_runstats.tables.$$


# Changes are likley not needed below this line
#----------------------------------------------------------------------------

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

# Initialize our own variables:
USER=
while getopts "u:" opt; do
    case "$opt" in
    u)  USER=$OPTARG
        ;;
    esac
done

shift `expr $OPTIND - 1`

[ "$1" = "--" ] && shift

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

# See if someone passed in DBAUTH as well
#if [ $# -gt 0 ]; then
 # DBAUTH=$*
#fi
#If authentication is needed, then one can set DBAUTH using environment variable.


# ensure that the schema is uppercase
SCHEMA=`echo $SCHEMA | tr '[:lower:]' '[:upper:]'`

# Get any tables specified on the command line
if [ $# -gt 0 ]; then
  TABLES=$*
fi

export DATABASE DBAUTH SCHEMA TABLES TABLE_SIZE_LIMIT TEMP_FILE

# Default options for runstats command
OPTIONS="on all columns with distribution and detailed indexes all"

# Find out DB2 version for runstats syntax
if db2level | grep "DB2 v7" > /dev/null; then
   echo Detected DB2 major version 7
   ACCESS="shrlevel change"
elif db2level | grep "DB2 v8" > /dev/null; then
   echo Detected DB2 major version 8
   ACCESS="allow write access"
elif db2level | grep "DB2 v9" > /dev/null; then
   echo Detected DB2 major version 9
   ACCESS="allow write access"
fi
export ACCESS

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

# Identify any special-case databases
## IBM Tivoli Directory Server
IS_ITDS=`db2 connect to $DATABASE $DBAUTH > /dev/null;
   db2 -x "select count(*) from SYSSTAT.TABLES where TABSCHEMA = '$SCHEMA' and TABNAME='LDAP_ENTRY'"`
if [ $IS_ITDS -eq 1 ]; then
   echo Detected IBM Tivoli Directory Server database
   # Get ITDS version and environment variables to determine whether we'll inflate certain table cardinalities
   if [ "$USER" = "" ]; then
       USER_SELECT=""
   else
       USER_SELECT="-u $USER"
   fi
   ITDS_VERSION=`$SCRIPTPATH/get_ids_instance_info.pl -q -o "version" $USER_SELECT`
   if [ $? -ne 0 ]; then
       echo ERROR: Could not determine ITDS version >&2
       exit
   fi
   echo ITDS Version $ITDS_VERSION
   echo "USER_SELECT=$USER_SELECT"
   ITDS_ENV_LDAP_MAXCARD=`$SCRIPTPATH/get_ids_instance_info.pl -q -o "env:LDAP_MAXCARD" $USER_SELECT`
   ITDS_ENV_IBMSLAPD_USE_SELECTIVITY=`$SCRIPTPATH/get_ids_instance_info.pl -q -o "env:IBMSLAPD_USE_SELECTIVITY" $USER_SELECT`
   if [ $? -ne 0 ]; then
       echo ERROR: Could not read ITDS configuration environment variables >&2
       exit
   fi
   echo "LDAP_MAXCARD=$ITDS_ENV_LDAP_MAXCARD"
   echo "IBMSLAPD_USE_SELECTIVITY=$ITDS_ENV_IBMSLAPD_USE_SELECTIVITY"
   if [ $ITDS_ENV_LDAP_MAXCARD = 'YES' ]; then
       ITDS_INFLATE_LDAP_CARD=1
   elif [ $ITDS_ENV_LDAP_MAXCARD = 'ONCE' ]; then
       ITDS_INFLATE_LDAP_CARD=1
   elif [ $ITDS_ENV_LDAP_MAXCARD = 'NO' ]; then
       ITDS_INFLATE_LDAP_CARD=0
   elif [ `$SCRIPTPATH/compare_versions.pl $ITDS_VERSION 6.3.1` -eq 1 ]; then
       ITDS_INFLATE_LDAP_CARD=0
   elif [ $ITDS_ENV_IBMSLAPD_USE_SELECTIVITY = 'YES' ]; then
       ITDS_INFLATE_LDAP_CARD=0
   else
       ITDS_INFLATE_LDAP_CARD=1
   fi
   if [ $ITDS_INFLATE_LDAP_CARD -eq 1 ]; then
       echo "Will inflate LDAP_DESC and LDAP_ENTRY cardinality.."
   else
       echo "Will NOT inflate LDAP_DESC and LDAP_ENTRY cardinality.."
   fi

   # change the database tuning options
   # Note: no need for "on all columns" or "detailed" indexes as ITDS uses
   # parameterized query markers.
   OPTIONS="and indexes all"

   ## IBM Tivoli Access Manager
   # TAM services within ITIM make use of the secAuthority attribute so we
   # need to not only check for the attribute's existance, but also to
   # get a count of how many entries have this attribute before confirming
   # that the product using ITDS is actually TAM
   HAS_SECAUTHORITY=`db2 connect to $DATABASE $DBAUTH > /dev/null;
      db2 -x "select count(*) from SYSSTAT.TABLES where TABSCHEMA = '$SCHEMA' and TABNAME='SECAUTHORITY'"`
   if [ $HAS_SECAUTHORITY -eq 1 ]; then
      IS_ITAM=`db2 connect to $DATABASE $DBAUTH > /dev/null;
         db2 -x "select count(*) from $SCHEMA.SECAUTHORITY"`
      if [ $IS_ITAM -gt 10 ]; then
         echo Detected IBM Tivoli Access Manager product
         PRODUCT="ITAM"
      fi
   fi
fi
## Tivoli Identity Manager
IS_ITIM=`db2 connect to $DATABASE $DBAUTH > /dev/null;
   db2 -x "select count(*) from SYSSTAT.TABLES where TABSCHEMA = '$SCHEMA' and (TABNAME='ERPARENT' or TABNAME='PROCESSLOG')"`
if [ $IS_ITIM -eq 1 ]; then
   echo Detected IBM Tivoli Identity Manager product
   PRODUCT="ITIM"
fi

## Role and Policy Modeler
IS_RAPM=`db2 connect to $DATABASE $DBAUTH > /dev/null;
   db2 -x "select count(*) from SYSSTAT.TABLES where TABSCHEMA = '$SCHEMA' and (TABNAME='ROLE_HIERARCHY' or TABNAME='IMPORT_MESSAGES')"`
if [ $IS_RAPM -eq 1 ]; then
   echo Detected IBM Security Role and Policy Modeler product
   PRODUCT="RAPM"
fi

export OPTIONS PRODUCT

do_runstats_on_table() {
   SCHEMA=$1
   TABLE=$2
   TABLE_SIZE=0

   # uses global variables:
   #   TEMP_FILE, TABLE_SIZE_LIMIT, OPTIONS, ACCESS

   echo Table: $SCHEMA.$TABLE
   if [ $TABLE_SIZE_LIMIT -gt 0 ]; then
      # check the table card value first 
      TABLE_SIZE=`egrep "^$TABLE " $TEMP_FILE | awk '{print $2}'`

      # if the table wasn't found in the list, for whatever reason,
       # set the TABLE_SIZE to 0
      if [ "x$TABLE_SIZE" = "x" ]; then
         TABLE_SIZE=0
      fi

      # if the card is >= 50000 (smallest artificial card),
      # use the colcard value instead
      if [ $TABLE_SIZE -ge 50000 ]; then
         TABLE_SIZE=`egrep "^$TABLE " $TEMP_FILE | awk '{print $3}'`
      fi

   fi

   if [ $TABLE_SIZE_LIMIT -eq 0 -o $TABLE_SIZE -lt $TABLE_SIZE_LIMIT ]; then
      echo  "   gathering statistics... "
      db2 runstats on table $SCHEMA.$TABLE $OPTIONS $ACCESS
   else
      echo "   skipping - size of table is $TABLE_SIZE which is >= $TABLE_SIZE_LIMIT"
   fi
}

do_card_tunings_for_table() {
   SCHEMA=$1
   TABLE=$2

   CUSTOM_CARD=

   # uses global variables:
   #   PRODUCT, IS_ITDS, SCRIPTPATH, ITDS_VERSION, ITDS_INFLATE_LDAP_CARD

   # Generic ITDS tables
   if [ $IS_ITDS -eq 1 ]; then
       if [ $ITDS_INFLATE_LDAP_CARD -eq 1 ]; then
	   if [ $TABLE = 'LDAP_DESC' ]; then
	       CUSTOM_CARD=9E18
	   elif [ $TABLE = 'LDAP_ENTRY' ]; then
	       CUSTOM_CARD=9E18
	   fi
       fi
       if [ $TABLE = 'REPLCHANGE' ]; then
	   CUSTOM_CARD=9E18
       fi

       # ITAM-specific ITDS tables
       if [ $TABLE = 'SECAUTHORITY' ]; then
	   CUSTOM_CARD=9E10
       elif [ $TABLE = 'CN' -a "x$PRODUCT" = "xITAM" ]; then
	   CUSTOM_CARD=9E10
       fi
       
       # ITIM-specific ITDS tables
       if [ $TABLE = 'ERPARENT' ]; then
	   CUSTOM_CARD=9E10
       fi
   fi

   # ITIM DB tables
   if [ $TABLE = 'SIBOWNER' ]; then
      CUSTOM_CARD=50000
   elif [ $TABLE = 'SCHEDULED_MESSAGE' ]; then
      CUSTOM_CARD=50000
   elif [ $TABLE = 'PROCESS' ]; then
      CUSTOM_CARD=50000
   elif [ $TABLE = 'ACTIVITY' ]; then
      CUSTOM_CARD=50000
   elif [ $TABLE = 'PROCESSDATA' ]; then
      CUSTOM_CARD=50000
   fi

# RAPM DB tables
   if [ $TABLE = 'IMPORT_MESSAGES' ]; then
      CUSTOM_CARD=50000
   fi

   if [ "x$CUSTOM_CARD" != "x" ]; then
      echo "   updating cardinality if it is < $CUSTOM_CARD (SQL0100Ws can be safely ignored)"
      db2 "update SYSSTAT.TABLES SET CARD = $CUSTOM_CARD where TABNAME = '$TABLE' AND CARD < $CUSTOM_CARD"
   fi
}

# print out some useful header information
echo
if [ "x$TABLES" = "x" ]; then
   echo Performing runstats on all tables for schema $SCHEMA
else
   echo Performing runstats on tables: $TABLES for schema $SCHEMA
fi
echo "   with options: $OPTIONS $ACCESS"
if [ $TABLE_SIZE_LIMIT -gt 0 ]; then
   echo "   skipping tables whose size is >= $TABLE_SIZE_LIMIT based on last runstats"
   echo "      using temp file $TEMP_FILE"
fi

# pull out the current TABNAME, CARD and MAX(COLCARD) values into a temporary
# file for skipping tables over TABLE_SIZE_LIMIT if applicable.
# the temp file is also used when doing runstats on all tables
db2 -x "select SYSSTAT.TABLES.TABNAME, CARD, MAX(COLCARD) from SYSSTAT.TABLES, SYSSTAT.COLUMNS where SYSSTAT.TABLES.TABNAME=SYSSTAT.COLUMNS.TABNAME and SYSSTAT.TABLES.TABSCHEMA = '$SCHEMA' group by SYSSTAT.TABLES.TABNAME, CARD order by SYSSTAT.TABLES.TABNAME" > $TEMP_FILE

if [ "x$TABLES" = "x" ]; then
   # Do runstats on all tables
   for TABLE in `cat $TEMP_FILE | awk '{print $1}'`
   do
      # make sure table name is uppercase
      TABLE=`echo $TABLE | tr '[:lower:]' '[:upper:]'`

      do_runstats_on_table $SCHEMA $TABLE
      do_card_tunings_for_table $SCHEMA $TABLE

      # set TABLES so we'll know we found some
      TABLES="$TABLES $TABLE"
   done
else
   # Do runstats on tables that were specified on the command line
   for TABLE in $TABLES
   do
      # make sure table name is uppercase
      TABLE=`echo $TABLE | tr '[:lower:]' '[:upper:]'`

      do_runstats_on_table $SCHEMA $TABLE
      do_card_tunings_for_table $SCHEMA $TABLE
   done
fi

# clean up temporary file if it exists
if [ -f $TEMP_FILE ]; then
   rm $TEMP_FILE
fi

# If no tables were found, or specified, print some helpful information about
# getting the right schema names
if [ "x$TABLES" = "x" ]; then
  echo
  echo WARNING:
  echo No tables found, your schema \($SCHEMA\) may be incorrect.
  echo The following schemas are available:
  db2 -x "select distinct cast(TABSCHEMA as varchar(30)) as TABSCHEMA from SYSSTAT.TABLES"
  exit
fi

# vim: sw=3 ts=3 expandtab
