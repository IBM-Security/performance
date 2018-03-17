@REM #!/bin/ksh
@REM ##############################################################################
@REM # 
@REM # Licensed Materials - Property of IBM
@REM # 
@REM # Restricted Materials of IBM
@REM # 
@REM # (C) COPYRIGHT IBM CORP. 2002, 2003, 2004, 2005, 2006. All Rights Reserved.
@REM # 
@REM # US Government Users Restricted Rights - Use, duplication or
@REM # disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
@REM # 
@REM ############################################################################## 
@REM #
@REM # Script:  tune_runstats.bat
@REM #
@REM # Author:  Richard Macbeth, IBM/Tivoli Services
@REM #
@REM # Description:  This script runs the db2 runstats command on one or more 
@REM #      tables for a given database and schema. It autodetects the db2 version 
@REM #      using db2level and passes the appropriate string to runstats to 
@REM #      allow writes to occur during the runstats.
@REM #
@REM # Prerequisites:  
@REM #      Run this command as the user for the database (ie: one that
@REM #      has connect and runstats abilities and permissions).
@REM #
@REM # Change History:  
@REM #      2006/10/18 Version 3.3 -  Michael Seedorff, IBM/Tivoli Services
@REM #         Added Windows Support with this bat file.
@REM #  
@REM #      2005/10/16 Version 3.2 -  Michael Seedorff
@REM #         Changed the command line parameters to use -db database
@REM #         and -s schema.  The position of parameters is now irrelevant,
@REM #         which makes it easier to add parameters in the future.
@REM #
@REM #         Added usage statement.
@REM #
@REM #      2005/10/16 Version 3.1 -  Richard Macbeth 
@REM #         After further testing we found that it is best to add the 
@REM #         card change for ldap_desc for use with ITIM and TAM searches
@REM #
@REM #      2005/??/?? Version 3.0 -  Richard Macbeth 
@REM #         Clean up script and removed remarked sections out
@REM #
@REM #      2005/05/05 Version 2.8 -  Richard Macbeth 
@REM #         Remarked out all card changes since they are not needed when 
@REM #         you have applied FixPack 9 to DB2 8.1 making it 8.2.2 The only 
@REM #         thing this script does now is runstats and a reorgchk on current 
@REM #         stats at the end.  Unremark them if you are not using DB2 8.2.2.
@REM #
@REM #         Changed out db2 command to gather all the tables except REPLCHANGE 
@REM #         this table should not have runstats run against it because most of 
@REM #         the time this table is empty and the optimation will not be correct 
@REM #         if runstats is run against it.
@REM #
@REM #      2005/04/03 Version 2.6 -  Richard Macbeth 
@REM #         Changed the options for runstats from
@REM #         OPTIONS="with distribution and sampled detailed indexes all"  
@REM #         to running OPTIONS="and sampled detailed indexes all".
@REM #
@REM #         Changed the script and added the reorgchk function at the end  
@REM #         and changed the options for that also.  It used to say:
@REM #         OPTIONS="update statistics on table all" and now its says:
@REM #         OPTIONS2="current statistics on table all" this way it will not run a
@REM #         runstats when it runs the reorgchk. this part now only take a few  
@REM #         seconds to generate the reorgchk.out file for someone to look at it.
@REM #         Also change OPTIONS to OPTIONS2 so it will have a unique value in 
@REM #         this script since runstats portion uses the same varable.
@REM #
@REM #      2004/11/24 Version 2.0 -  Richard Macbeth 
@REM #         Deleted the card chage to the ldap_entry table to fix the 
@REM #         modifyTimeStamp query now query is sub second
@REM #
@REM #      2002/01/01 Version 1.0 -  Richard Macbeth 
@REM #         Original Version
@REM #


@echo off

set THISFILE=%~f0
set FILEDIR=%~dp0
set THISARGS=%*
set ORIGDIR=%CD%
@setlocal


goto ENDUSAGE
@REM ####################### USAGE STATEMENT ##############################
:USAGE
if not "%ERRMSG%"=="" echo %ERRMSG%
echo.
echo USAGE:
echo.
echo.  tune_runstats [ -s schema ] [ -I DB2Instance ] [ -db dbname ] [ -o file ]
echo                  [ -? ]  prints usage message
echo                  [ -h ]  prints usage message
echo                  [ -help ]  prints usage message
echo.
echo     Options:
echo        -I DB2Instance  DB2 Instance name  (Defaults to DB2INSTANCE for user)
echo        -db dbname      DB name to update (Default=ldapdb2)
echo        -s  schema      Schema name (Default=LDAPDB2)
echo        -o  file        Filename for output of reorgchk (Default=reorgchk.out)
echo.
echo   Note:  This command must be run from a DB2 command line processor (db2cmd)

goto END
@REM ################### END USAGE STATEMENT ##############################
:ENDUSAGE


goto ENDERRMG
@REM ###################### ERROR MESSAGES ################################

:INVALID
   set ERRMSG=ISST8118E: Invalid option - %PARAM1%
   set RC=18
   goto USAGE

:NODB2CMD
   set ERRMSG=ISST8121E: This command must be executed from a DB2 command line.
   set RC=21
   goto PRTEXIT

:CONNFAIL
   set ERRMSG=ISST8122E: Unable to connect to database %DBNAME% on instance %DB2INSTANCE%.
   db2 terminate 2>&1 > NUL
   set RC=22
   goto PRTEXIT

:DB2FAIL
   set ERRMSG=ISST8123E: A DB2 command returned an error - %CMD%.
   db2 terminate 2>&1 > NUL
   set RC=23
   goto PRTEXIT

:DIRNF
   set ERRMSG=ISST8125E: Directory not found - %MISSDIR%.
   set RC=25
   goto PRTEXIT

:SCHMFAIL
   set ERRMSG=ISST8126E: Table list for schema failed. Verify that the schema name is correct.
   db2 terminate 2>&1 > NUL
   set RC=26
   goto PRTEXIT

:LOOPERR
   set ERRMSG=ISST8177E: No return label set in loop %LOOPNAME%.
   set RC=77
   goto PRTEXIT

@REM ################## END ERROR MESSAGES ################################
:ENDERRMG

@REM Parse command line arguments
:GETARG
set PARAM1=%~1
IF "%PARAM1%"=="" goto SETDEF
IF "%PARAM1%"=="-debug" goto SETTRC
IF "%PARAM1%"=="-I" goto SETINST
IF "%PARAM1%"=="-db" goto SETDB
IF "%PARAM1%"=="-s" goto SETSCHEM
IF "%PARAM1%"=="-o" goto SETOUTF
IF "%PARAM1%"=="-?" goto USAGE
IF "%PARAM1%"=="-h" goto USAGE
IF "%PARAM1%"=="-help" goto USAGE
goto INVALID

:SETTRC
   set DEBUG=true
   SHIFT
   goto GETARG
:SETINST
   set DB2INSTANCE=%~2
   IF "%DB2INSTANCE%"=="" goto USAGE
   SHIFT && SHIFT
   goto GETARG
:SETDB
   set DBNAME=%~2
   IF "%DBNAME%"=="" goto USAGE
   SHIFT && SHIFT
   goto GETARG
:SETSCHEM
   set SCHEMA=%~2
   IF "%SCHEMA%"=="" goto USAGE
   SHIFT && SHIFT
   goto GETARG
:SETOUTF
   set OUTFILE=%~2
   IF "%OUTFILE%"=="" goto USAGE
   if not exist "%~dp2" set MISSDIR=%~dp2 && goto DIRNF
   SHIFT && SHIFT
   goto GETARG

:SETDEF
   @REM # Setup Default variable settings
   if "%DB2INSTANCE%"=="" set DB2INSTANCE=ldapdb2
   if "%DBNAME%"=="" set DBNAME=ldapdb2
   if "%SCHEMA%"=="" set SCHEMA=ldapdb2
   if "%DEBUG%"=="" set DEBUG=false
   if "%OUTFILE%"=="" set OUTFILE=%FILEDIR%reorgchk.out

   @REM # Options for reorgchk command
   set OPTIONS2=current statistics on table all

   @REM # Default options for runstats command
   @REM # Find out DB2 version for runstats syntax
:V7OPTS
   db2level | findstr /C:"DB2 v7" > NUL
   if not "%ERRORLEVEL%"=="0" goto V8OPTS
      echo Detected DB2 major version 7
      set ACCESS=shrlevel change
      set OPTIONS=WITH DISTRIBUTION AND SAMPLED DETAILED INDEXES ALL
:V8OPTS
   db2level | findstr /C:"DB2 v8" > NUL
   if "%ERRORLEVEL%"=="0" echo Detected DB2 major version 8
      set ACCESS=allow write access
      set OPTIONS=WITH DISTRIBUTION ON ALL COLUMNS AND SAMPLED DETAILED INDEXES ALL
:ENDDEF


:PRTSTART
if "%DEBUG%"=="false" goto ENDPRTST
echo ########################################################### 
date /T 
time /T 
echo SCRIPT:   %THISFILE%
echo ARGS:     %THISARGS%
echo ##################### Begin ###############################
echo. 
echo   VARIABLES:
echo      DB2INSTANCE=%DB2INSTANCE%
echo      DBNAME=%DBNAME%
echo      DEBUG=%DEBUG%
echo      DB2CLP=%DB2CLP%
echo      OPTIONS (runstats) =%OPTIONS%
echo      ACCESS (runstats) =%ACCESS%
echo      OPTIONS2 (reorgchk) =%OPTIONS2%
echo. 
:ENDPRTST

@REM ###################### ERROR CHECKING ################################
:PROPCHECK

   @REM Verify that this is a DB2 command line processor window
   if "%DB2CLP%"=="" @echo off && goto NODB2CMD
   
   @REM # Ensure that DB2 has been started
   if "%DEBUG%"=="true" db2start 2>&1 
   if not "%DEBUG%"=="true" db2start 2>&1 > NUL

   set CMD=db2 connect to %DBNAME% 
   if "%DEBUG%"=="true" goto CONNDBG
   %CMD% 2>&1 > NUL 
   if not "%ERRORLEVEL%"=="0" @echo off && goto CONNFAIL
   set ISDB2CONN=true 
   goto SCHMTEST
:CONNDBG
   %CMD% 
   if not "%ERRORLEVEL%"=="0" @echo off && goto CONNFAIL
   set ISDB2CONN=true 
:SCHMTEST
   set CMD=db2 list tables for schema %SCHEMA%
   if "%DEBUG%"=="true" goto SCHMDBG
   %CMD% 2>&1 > NUL 
   if not "%ERRORLEVEL%"=="0" @echo off && goto SCHMFAIL
   goto ENDSCHM
:SCHMDBG
   %CMD% 
   if not "%ERRORLEVEL%"=="0" @echo off && goto SCHMFAIL
:ENDSCHM

@REM ################## END ERROR CHECKING ################################
:ENDCHECK


@REM ########################### MAIN SECTION #############################
@REM # Ensure that DB2 has been started
if "%DEBUG%"=="true" db2start 2>&1 
if not "%DEBUG%"=="true" db2start 2>&1 > NUL

if "%DEBUG%"=="true" db2 get instance
if "%DEBUG%"=="true" db2 list db directory
if "%DEBUG%"=="true" @echo on
@REM ALREADY CONNECTED BECAUSE OF ERROR CHECKING SECTION
@REM db2 connect to %DBNAME% 
@REM if not "%ERRORLEVEL%"=="0" @echo off && goto CONNFAIL

@REM # Execute runstats on all tables
echo.
echo Performing runstats on all tables for schema %SCHEMA%
echo    with options: %OPTIONS% %ACCESS%
echo.
set TEMPFILE=%TEMP%\db2_table_list.txt
if exist "%TEMPFILE%" del /Q "%TEMPFILE%"
db2 -x "select rtrim(tabschema) concat '.' concat rtrim(tabname) from syscat.tables where type ='T' and tabname not in('REPLCHANGE')" > "%TEMPFILE%"
for /F %%i in (%TEMPFILE%) do db2 runstats on table %%i %OPTIONS% %ACCESS%
if exist "%TEMPFILE%" del /Q "%TEMPFILE%"

@REM # Since this is an LDAP database, update LDAP_DESC and LDAP_ENTRY 
@REM # stats in the statistics table.  Comment out these lines if you are 
@REM # having problems after you are running with or on DB2 8.2.2/8.1.9
@REM # and above with reopt=3 statement.  
@REM # Only reinstate LDAP_ENTRY if you really need to after full testing.
if "%DEBUG%"=="true" echo Updating LDAP_DESC stats in the statistics table
db2 "update sysstat.tables set card = 9E18 where tabname = 'LDAP_DESC'"
@REM if "%DEBUG%"=="true" echo Updating LDAP_ENTRY stats in the statistics table
@REM db2 "update sysstat.tables set card = 9E18 where tabname = 'LDAP_ENTRY'"

@REM # Run a reorgchk and generate an output file.  The file can be 
@REM # looked at to determine if a reorg of a table or index is needed.  If a 
@REM # reorg is needed you will need to stop the server to do the reorg and 
@REM # then after a reorg is done you will have to re-run this script before 
@REM # starting  the LDAP server.


@REM # Execute reorgchk on all tables
echo.
echo Performing reorgchk on Database: %DATABASE% for schema %SCHEMA%
echo   with options: %OPTIONS2% 
set CMD=db2 reorgchk %OPTIONS2% 
%CMD% > "%OUTFILE%"
if not %ERRORLEVEL% LEQ 3 @echo off && goto DB2FAIL
echo.
echo Results of the check are located in "%OUTFILE%".  
echo View the file and perform a reorg for the indicated tables.
set CMD=db2 terminate
%CMD% > NUL
if not %ERRORLEVEL% LEQ 3 @echo off && goto DB2FAIL

@REM ########################## END MAIN SECTION ##########################

:PRTEXIT
@echo off
if not "%ERRMSG%"=="" echo. && echo %ERRMSG%
if not "%DEBUG%"=="true" goto ENDPRTEX
echo. 
echo ###################### End ################################
date /T 
time /T 
echo ########################################################### 
echo. 
:ENDPRTEX

:END
if "%ISDB2CONN%"=="true" db2 terminate 2>&1 > NUL
cd /d "%ORIGDIR%"
@endlocal
if NOT "%RC%"=="" exit /b %RC% 
@endlocal
exit /b 0

