@REM #!/bin/sh
@REM ##############################################################################
@REM # 
@REM # Licensed Materials - Property of IBM
@REM # 
@REM # Restricted Materials of IBM
@REM # 
@REM # (C) COPYRIGHT IBM CORP. 2006. All Rights Reserved.
@REM # 
@REM # US Government Users Restricted Rights - Use, duplication or
@REM # disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
@REM # 
@REM ############################################################################## 
@REM #
@REM # Script:  db2perf.bat
@REM #
@REM # Author:  Michael Seedorff, IBM/Tivoli Services
@REM #
@REM # Description:  This script creates the necessary bindings to use the
@REM #      REOPT command and increase performance for the DB2 database.  
@REM # 
@REM # Prerequisites:  
@REM #      This script must be executed by the owner of the DB2 instance in which
@REM #         the specified database resides.  The default database is ldapdb2.
@REM #
@REM # Change History:                                                      
@REM #      2006/10/17 Version 1.1 -  Michael Seedorff, IBM/Tivoli Services 
@REM #         Added Windows Support with this bat file.
@REM #                                                                      
@REM #      2006/02/10 Version 1.0 -  Michael Seedorff, IBM/Tivoli Services 
@REM #         Original version.                                            
@REM #                                                                      

@REM @echo on
@echo off

set THISFILE=%~f0
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
echo   db2perf  [ -I DB2Instance ] [ -db dbname ] [ -db2dir sqllib ]
echo                  [ -? ]  prints usage message
echo                  [ -h ]  prints usage message
echo                  [ -help ]  prints usage message
echo.
echo   Options:
echo     -I DB2Instance  DB2 Instance name  (Defaults to DB2INSTANCE for user)
echo     -db dbname      DB name to update with bind scripts (Default=ldapdb2)
echo     -db2dir sqllib  Location of SQLLIB directory - must contain bnd dir
echo                        (Default=C:\Program Files\IBM\SQLLIB)
echo.
echo   Note:  This command must be run from a DB2 command line processor (db2cmd)
echo.
if "%RC%"=="" set RC=10
goto END
@REM ################### END USAGE STATEMENT ##############################
:ENDUSAGE


@REM ##################### CONSTANTS STATEMENT #############################
@REM set MYVAR=value
@REM ################## END CONSTANTS STATEMENT ############################


goto ENDERRMG
@REM ###################### ERROR MESSAGES ################################

:INVALID
   set ERRMSG=ISST8118E: Invalid option - %PARAM1%
   set RC=18
   goto USAGE

:DB2DIRNF
   set ERRMSG=ISST8119E: Directory %DB2DIR% not found.  Verify db2dir is correct.
   set RC=19
   goto PRTEXIT

:DB2BNDNF
   set ERRMSG=ISST8120E: Directory %DB2DIR%\bnd not found.  Verify db2dir is correct.
   set RC=20
   goto PRTEXIT

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

@REM ################## END ERROR MESSAGES ################################
:ENDERRMG

@REM Parse command line arguments
:GETARG
set PARAM1=%~1
IF "%PARAM1%"=="" goto SETDEF
IF "%PARAM1%"=="-debug" goto SETTRC
IF "%PARAM1%"=="-I" goto SETINST
IF "%PARAM1%"=="-db" goto SETDB
IF "%PARAM1%"=="-db2dir" goto SETDBDIR
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
:SETDBDIR
   set DB2DIR=%~2
   IF "%DB2DIR%"=="" goto USAGE
   SHIFT && SHIFT
   goto GETARG

:SETDEF
   @REM # Setup Default variable settings
   if "%DB2INSTANCE%"=="" set DB2INSTANCE=ldapdb2
   if "%DBNAME%"=="" set DBNAME=ldapdb2
   if "%DB2DIR%"=="" set DB2DIR=C:\Program Files\IBM\SQLLIB
   if "%BNDDIR%"=="" set BNDDIR=%DB2DIR%\bnd
   if "%DEBUG%"=="" set DEBUG=false
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
echo      DB2DIR=%DB2DIR%
echo      BNDDIR=%BNDDIR%
echo      DEBUG=%DEBUG%
echo      DB2CLP=%DB2CLP%
echo. 
:ENDPRTST

@REM ###################### ERROR CHECKING ################################
:PROPCHECK

   @REM Verify that the DB2 directory exists
   if not exist "%DB2DIR%" @echo off && goto DB2DIRNF
   @REM Verify that the DB2 SQLLIB/bnd directory exists
   if not exist "%BNDDIR%" @echo off && goto DB2BNDNF
   @REM Verify that this is a DB2 command line processor window
   if "%DB2CLP%"=="" @echo off && goto NODB2CMD

@REM ################## END ERROR CHECKING ################################
:ENDCHECK


@REM ########################### MAIN SECTION #############################
cd /d "%BNDDIR%"

if "%DEBUG%"=="true" db2 get instance
if "%DEBUG%"=="true" db2 list db directory
if "%DEBUG%"=="true" @echo on
@REM # Ensure that DB2 has been started
if "%DEBUG%"=="true" db2start 2>&1 
if not "%DEBUG%"=="true" db2start 2>&1 > NUL

db2 connect to %DBNAME% 
if not "%ERRORLEVEL%"=="0" @echo off && goto CONNFAIL
set ISDB2CONN=true 
set CMD=db2 bind @db2ubind.lst BLOCKING ALL GRANT PUBLIC
%CMD%
if not %ERRORLEVEL% LEQ 3 goto DB2FAIL
set CMD=db2 bind @db2cli.lst BLOCKING ALL GRANT PUBLIC
%CMD%
if not %ERRORLEVEL% LEQ 3 goto DB2FAIL
set CMD=db2 bind db2schema.bnd BLOCKING ALL GRANT PUBLIC sqlerror continue
%CMD%
if not %ERRORLEVEL% LEQ 3 goto DB2FAIL
set CMD=db2 bind db2clipk.bnd collection NULLIDR1
%CMD%
if not %ERRORLEVEL% LEQ 3 goto DB2FAIL
set CMD=db2 bind db2clipk.bnd collection NULLIDRA
%CMD%
if not %ERRORLEVEL% LEQ 3 goto DB2FAIL
set CMD=db2 commit
%CMD%
if not %ERRORLEVEL% LEQ 3 goto DB2FAIL
set CMD=db2 terminate
%CMD%
if not %ERRORLEVEL% LEQ 3 goto DB2FAIL
@if "%DEBUG%"=="true" @echo off

@REM ########################## END MAIN SECTION ##########################

:PRTEXIT
if not "%ERRMSG%"=="" echo %ERRMSG%
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

