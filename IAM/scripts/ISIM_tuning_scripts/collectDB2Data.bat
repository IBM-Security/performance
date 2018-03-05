@echo off

REM collectDB2Data.bat
REM Author: Casey Peel (cpeel@us.ibm.com)
REM Last Updated: 2009/06/02 1731 MDT
REM Description:
REM    This script will collect various information from the specified DB2
REM    database to determine if all of the desired tunings have been
REM    applied.
REM
REM    This script should be run in a DB2 command window (db2cmd) and have
REM    write permission to the current working directory (or TEMP should
REM    be updated to a directory with write permissions).
REM
REM    Ensure that you have the DB2INSTANCE environment variable set
REM    correctly or the data collection will fail!
REM Usage:
REM    collectDB2Data.bat database [USER username USING password]
REM
REM NOTE: Unlike the Unix versions of this script, the Windows version does
REM not do any sanity checking on the output - the user is responsible for
REM verifying that valid data was collected before sending it to support!


REM Directory to store collected information - this directory must be writeable
set TEMP=.

REM ----------------------------------------------------------------------

REM DATA must not be modified. Update TEMP if you wish to put the contents
REM in a different directory
set DATA=%TEMP%\db2Data

REM ----------------------------------------------------------------------

REM Detect argument DATABASE if it is passed into the script
set DATABASE=%1
set DBAUTH=%2 %3 %4 %5

echo Connecting to %DATABASE% %DBAUTH%
db2 connect to %DATABASE% %DBAUTH%

echo Creating storage directory %DATA%
mkdir %DATA%

REM now start collecting data

echo Storing the OS type
echo Windows > %DATA%\os.name

echo Storing the name of the database
echo %DATABASE% > %DATA%\db.name

echo Getting the database level
db2level > %DATA%\db2level.out

echo Getting the db2 env data
db2set > %DATA%\db2set.out

echo Getting dbm config
db2 get dbm cfg > %DATA%\dbm.cfg

echo Getting db config
db2 get db cfg for %DATABASE% show detail > %DATA%\db.cfg

echo Getting bufferpool information
db2 "select bpname,npages,pagesize from syscat.bufferpools" > %DATA%\bufferpools.out

echo Getting statistics information
db2 "select tabschema,tabname,card from sysstat.tables order by card" > %DATA%\cardinalities.out
db2 "select tabschema,tabname,stats_time from syscat.tables order by stats_time" > %DATA%\runstats_times.out

echo Getting composite snapshot
db2 get snapshot for all on %DATABASE% > %DATA%\snapshot.out

echo Getting table definitions
db2look -d %DATABASE% -e > %DATA%\tables.ddl

echo Data resides in file %TEMP%\db2Data

REM vim: sw=3 ts=3 expandtab
