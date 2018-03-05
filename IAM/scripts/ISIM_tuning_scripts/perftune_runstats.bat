@echo off

rem perftune_runstats.bat
rem Author: Gowree Venkatachalam (gowree@us.ibm.com)
rem         Casey Peel (cpeel@us.ibm.com)
rem         Nnaemeka Emejulu (eemejulu@us.ibm.com)
rem         Lidor Goren (lidor@us.ibm.com)
rem Last Updated: 2014/07/31 
rem Description
rem   Command script to run the db2 runstats command on all tables for a given 
rem   database and schema. It assumes the db2 version as 8 and passes the 
rem   appropriate string to runstats to allow writes to occur 
rem   during the runstats. 
rem Usage: 
rem   This script should be run as the user for the database (ie: one that
rem   has connect and runstats abilities and permissions). 
rem   This bat file should be executed either in a db2cmd window as:
rem      perftune_runstats.bat
rem   or from a regular command window as:
rem      db2cmd /c /w /i perftune_runstats.bat
rem   in order to have the db2 environment set up correctly.

rem   ####Latest ADDITIONS####
rem   # Date: 2014/7/31  By: Lidor Goren (lidor@us.ibm.com)
rem   # When version is 6.3.1 or higher we no longer artificially inflate cardinality for LDAP_DESC and LDAP_ENTRY table
rem   # Version needs to be set manually, however the check is automated through external batch file compare_versions.bat
rem   #######


setlocal
rem 
set   mypath=%~dp0

rem   The following two environment variables are initialized to ITIM defaults
rem   and may be replaced by the database name and schema name used for ITIM
rem   configuration.
set   DATABASE=itimdb
set   SCHEMA=ENROLE
rem   SCHEMATYPE should be set to ITIM if running runstats on ITIM's database
rem   regardless of what the DATABASE or SCHEMA names are set to
set   SCHEMATYPE=ITIM

rem   For ITDS's DB2 instance
rem set   DATABASE=ldapdb2
rem set   SCHEMA=LDAPDB2
rem   SCHEMATYPE should be set to ITDS if running runstats on an ITDS database
rem   regardless of what the DATABASE or SCHEMA names are set to
rem   ITDS_VERSION should be set to the correct ITDS version
rem set   SCHEMATYPE=ITDS
rem set   ITDS_VERSION=6.3

rem   For RaPM DB2 instance
rem set   DATABASE=rapmdb
rem set   SCHEMA=RAPMUSER
rem   SCHEMATYPE should be set to RAPM if running runstats on an RAPM database
rem   regardless of what the DATABASE or SCHEMA names are set to
rem set   SCHEMATYPE=RAPM

rem   Assuming DB2 version 8 -- set default ACCESS and OPTIONS
set   ACCESS=allow write access
set   OPTIONS=on all columns with distribution and detailed indexes all

rem   Handle special database types
if %SCHEMATYPE% == ITDS (
  echo  SCHEMATYPE set to IBM Tivoli Directory Server
  set OPTIONS="on all columns and detailed indexes all"
)

if  %SCHEMATYPE% == ITIM (
  echo  SCHEMATYPE set to IBM Tivoli Identity Manager
)

if  %SCHEMATYPE% == RAPM (
  echo  SCHEMATYPE set to IBM Security Role and Policy Modeler
)

echo  Connecting to %DATABASE% 
db2 connect to %DATABASE%

set   FILENAME=tables1.txt
echo  Retrieving all tables and storing them in %FILENAME%
db2 "select TABNAME,TABSCHEMA from SYSSTAT.TABLES where TABSCHEMA = '%SCHEMA%' order by TABNAME" | find "%SCHEMA%" > %FILENAME%


echo  Iterating over the tables.
for /F "tokens=1" %%i in (%FILENAME%) do (
  echo   Executing runstats on %SCHEMA%.%%i..
  db2 runstats on table %SCHEMA%.%%i %OPTIONS% %ACCESS%
)

rem   If the database we're tuning is an LDAP database, update LDAP_DESC and 
rem   LDAP_ENTRY stats in the statistics table. 

if %SCHEMATYPE% == ITDS (
  echo  Updating LDAP_DESC and LDAP_ENTRY stats in the statistics table.
  rem   # We are checking here to see if the version is 6.3.1 or higher. If it isn't we need to manipulate cardinality in two more tables
  for /f "tokens=*" %%a in ('%mypath%compare_versions.bat %ITDS_VERSION% 6.3.1') do set ver_check=%%a
  if not %ver_check% equ 1 (
    db2 "update sysstat.tables set card = 9E18 where tabname = 'LDAP_DESC' and card < 9E18"
    db2 "update sysstat.tables set card = 9E18 where tabname = 'LDAP_ENTRY' and card < 9E18"
  )
  db2 "update sysstat.tables set card = 9E10 where tabname = 'ERPARENT' and card <> 9E10"
  db2 "update sysstat.tables set card = 9E18 where tabname = 'REPLCHANGE' and card <> 9E10"
)

rem   If the database we're tuning is an ITIM database, update ACTIVITY, 
rem   PROCESS, PROCESSDATA, SCHEDULED_MESSAGE stats in the statistics table. 

if %SCHEMATYPE% == ITIM (
  echo  Updating ACTIVITY, PROCESS, PROCESSDATA, SCHEDULED_MESSAGE stats in the statistics table. 
  db2 "update sysstat.tables set card = 50000 where tabname = 'ACTIVITY' and card < 50000"
  db2 "update sysstat.tables set card = 50000 where tabname = 'PROCESS' and card < 50000"
  db2 "update sysstat.tables set card = 50000 where tabname = 'PROCESSDATA' and card < 50000"
  db2 "update sysstat.tables set card = 50000 where tabname = 'SCHEDULED_MESSAGE' and card < 50000"
)

if %SCHEMATYPE% == RAPM (
  echo  Updating IMPORT_MESSAGES stats in the statistics table. 
  db2 "update sysstat.tables set card = 50000 where tabname = 'IMPORT_MESSAGES' and card < 50000"
)
endlocal

:end