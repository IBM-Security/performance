#!/bin/sh

# collectITDSData.sh
# Author: Casey Peel (cpeel@us.ibm.com)
# Revision: Nnaemeka Emejulu (eemejulu@us.ibm.com)
# Last Updated: 2013/12/12 
# Description:
#    This script will collect various information from the ITDS instance
#    to determine if all of the desired tunings have been applied.
#
#    This script should be run as the ITDS instance owner and have
#    write permission to the current working directory (or TEMP should
#    be updated to a directory with write permissions).
# Usage:
#    ./collectITDSData.sh bindDN bindPassword [ tdsEtcDirectory ]

####Latest ADDITIONS####
#Date: 2013/12/12
#Modified default shell from bash to sh
#######

# Directory to store collected information - this directory must be writeable
TEMP=.
export TEMP

#----------------------------------------------------------------------

# DATA must not be modified. Update TEMP if you wish to put the contents
# in a different directory
DATA=$TEMP/tdsData
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

   $GREP -q "$STRING" $FILE
   if [ $? -ne 0 ]; then
      echo WARNING: File $FILE may not have desired contents!
      return 1
   fi

   return 0
}

#----------------------------------------------------------------------

# Get the login information
if [ $# -lt 2 ]; then
   echo ERROR: the bindDN and bindPassword must be specified as arguments:
   echo $0 bindDN bindPassword
   exit 1
fi

BINDDN=$1
BINDPW=$2
shift; shift

# Detect argument IDSETC if it is passed into the script
if [ $# -gt 0 ]; then
   IDSETC=$1
   shift
fi

# if no IDSETC was specified, try to determine it
if [ "$IDSETC" == "" ]; then
   IDSETC=`ls -d idsslapd-*/etc`
fi

# confirm we can find the instance home directory
if [ ! -f "$IDSETC/ibmslapd.conf" ]; then
   echo ERROR: Unable to locate TDS configuration file.
   echo Try specifying the path to the TDS instance etc/ directory
   echo on the command line, like:
   echo $0 bindDN bindPassword /home/ldapdb2/idsslapd-ldapdb2/etc
   exit 1
fi

# check to make sure the temp directory does not already exist
if [ -d $DATA ]; then
   echo ERROR: Data directory "($DATA)" exists. Remove or rename it to continue.
   exit 1
fi

echo "Creating storage directory $DATA"
mkdir $DATA
if [ ! -d $DATA ]; then
   echo ERROR: Unable to create data directory "($DATA)".
   exit 1
fi

# now start collecting data

echo "Storing the OS type"
echo $OS > $DATA/os.name

echo "Getting current user id"
id > $DATA/id.out

echo "Getting ulimit values for current user"
ulimit -a > $DATA/ulimit.out

mkdir $DATA/etc

echo "Copying ibmslapd.conf file"
cp $IDSETC/ibmslapd.conf $DATA/etc

echo "Copying schema files"
cp $IDSETC/V3* $DATA/etc

echo "Getting cn=monitor output"
ldapsearch -D $BINDDN -w $BINDPW -b "cn=monitor" -s base "objectclass=*" > $DATA/monitor.out
check_file_contents $DATA/monitor.out "version="

echo "Getting audit settings"
ldapsearch -D $BINDDN -w $BINDPW -b "cn=Audit,cn=Log Management,cn=Configuration" -s base "objectclass=*" > $DATA/audit.out
check_file_contents $DATA/audit.out "ibm-audit"

# finished collecting data, package it up

echo "tar'ing up contents"
PWD=`pwd`
cd $TEMP
tar cf tdsData.tar tdsData
if [ $? -eq 0 ]; then
   # sanity check that $DATA is a valid directory before wiping it
   if [ -d $DATA -a "$DATA" != "/" ]; then
      echo "Removing temporary directory"
      rm $DATA/etc/*
      rmdir $DATA/etc
      rm $DATA/*
      rmdir $DATA
   else
      echo "WARNING: Leaving temporary directory ($DATA) as there was some uncertainty about removing it."
   fi

   echo
   echo "Data resides in file $TEMP/tdsData.tar"
else
   echo "WARNING: Unable to tar up the $TEMP/tdsData directory. Directory and contents will be left as-is."

   echo
   echo "Data resides in directory $TEMP/tdsData"
fi
cd $PWD

# vim: sw=3 ts=3 expandtab
