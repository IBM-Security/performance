@echo off

REM collectITDSData.bat
REM Author: Casey Peel (cpeel@us.ibm.com)
REM Last Updated: 2009/06/02 1737 MDT
REM Description:
REM    This script will collect various information from the ITDS instance
REM    to determine if all of the desired tunings have been applied.
REM
REM    This script should be run as a user with read access to the ITDS
REM    configuration files and have write permissions to the current
REM    working directory (or TEMP should be updated to a directory with
REM    write permissions).
REM Usage:
REM    collectITDSData.bat "bindDN" "bindPassword" "tdsEtcDirectory"
REM Tip:
REM    Include quotes around the variables you pass into the script or
REM    the Windows command interpreter may parse them oddly (ie: cn=root
REM    might get parsed as two separate arguments instead of one).
REM
REM NOTE: Unlike the Unix versions of this script, the Windows version does
REM not do any sanity checking on the output - the user is responsible for
REM verifying that valid data was collected before sending it to support!


REM Directory to store collected information - this directory must be writeable
set TEMP=.

REM ----------------------------------------------------------------------

REM DATA must not be modified. Update TEMP if you wish to put the contents
REM in a different directory
set DATA=%TEMP%\tdsData

REM ----------------------------------------------------------------------

set BINDDN=%1
set BINDPW=%2
set IDSETC=%3

echo Creating storage directory %DATA%
mkdir %DATA%

REM now start collecting data

echo Storing the OS type
echo Windows > %DATA%\os.name

echo Creating subdirectory %DATA%\etc
mkdir %DATA%\etc

echo Copying ibmslapd.conf file
copy %IDSETC%\ibmslapd.conf %DATA%\etc

echo Copying schema files
copy %IDSETC%\V3* %DATA%\etc

echo Getting cn=monitor output
call ldapsearch -D %BINDDN% -w %BINDPW% -b "cn=monitor" -s base "objectclass=*" > %DATA%\monitor.out

echo Getting audit settings
call ldapsearch -D %BINDDN% -w %BINDPW% -b "cn=Audit,cn=Log Management,cn=Configuration" -s base "objectclass=*" > %DATA%\audit.out

echo Data resides in %TEMP%\tdsData

REM vim: sw=3 ts=3 expandtab
