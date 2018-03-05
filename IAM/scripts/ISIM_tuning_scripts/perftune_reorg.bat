@echo off

rem   Desription: 
rem   Command script to run the db2 reorg command on all tables for a given 
rem   database and schema.
rem   Usage: 
rem      This script should be run as the user for the database (ie: one that
rem      has connect and reorg abilities and permissions). 
rem      This cmd file should be executed either in a db2cmd window as:
rem         perftune_reorg.bat
rem      or from a regular command window as:
rem         db2cmd /c /w /i perftune_reorg.bat

setlocal

rem   The following two environment variables are initialized to ITIM defaults
rem   and may be replaced by the database name and schema name used for ITIM
rem   configuration.
set   DATABASE=itimdb
set   SCHEMA=ENROLE

rem   For ITDS's DB2 instance
rem set   DATABASE=ldapdb2
rem set   SCHEMA=LDAPDB2

echo  Connecting to %DATABASE% 
db2 connect to %DATABASE%

set   FILENAME=tables1.txt
echo  Retrieving all tables and storing them in %FILENAME%
db2 "select TABNAME,TABSCHEMA from SYSSTAT.TABLES where TABSCHEMA = '%SCHEMA%' order by TABNAME" | find "%SCHEMA%" > %FILENAME%

echo  Iterating over the tables..
for /F "tokens=1" %%i in (%FILENAME%) do (
  echo   Executing reorg on %SCHEMA%.%%i..
  db2 reorg table %SCHEMA%.%%i
  db2 reorg indexes all for table %SCHEMA%.%%i
)

endlocal
