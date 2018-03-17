@REM #/bin/ksh
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
@REM # Script:  db2_tunings.bat
@REM #
@REM # Author:  Richard Macbeth, IBM/Tivoli Services
@REM #
@REM # Description:  
@REM #
@REM # Prerequisites:  
@REM #      This script must be run under the context of the DB2 instance
@REM #         owner (ldapdb2).  It does not require write authority to the 
@REM #         current directory.  
@REM #
@REM #      The LDAP Server must be stopped. This script will stop and start
@REM #         the DB2 instance.
@REM #
@REM # Usage:
@REM #      See "usage" block below or run  db2_tunings.sh -?
@REM #
@REM #  (For windows servers start with -s 1024 for 32 bit OS's)
@REM #
@REM # Change History:
@REM #      2006/10/18 Version 2.4 -  Michael Seedorff, IBM/Tivoli Services
@REM #         Added Windows Support with this bat file.
@REM #  
@REM #      2006/08/29 Version 2.3 -  Michael Seedorff, IBM/Tivoli Services
@REM #         Updated estimate code for AIX to report MB.  
@REM #         Added estimate code for Linux.
@REM #         Truncated the decimal point and 00 that from the estimate (all OSes).
@REM #  
@REM #      2006/04/29 Version 2.2 -  Richard Macbeth, IBM/Tivoli Services
@REM #         Deleted INTRA_PARALLEL, DFT_DEGREE, and max_querydegree from script. 
@REM #            LDAP uses default setting for these settings. 
@REM #  
@REM #         Updated comments.
@REM #  
@REM #      2006/03/31 Version 2.1 -  Richard Macbeth, IBM/Tivoli Services
@REM #         Added and Change variuos settings such as: 
@REM #            MAXAPPLS, MAXFILOP, DFT_PREFETCH_SZ, DFT_EXTENT_SZ, 
@REM #            LOCKTIMEOUT, LOCKLIST, DBHEAP, CATALOGCACHE_SZ
@REM #
@REM #         Changed IOCLEANERS to IOSERVERS + 4.
@REM #
@REM #      2006/02/20 Version 2.0 -  Michael Seedorff, IBM/Tivoli Services
@REM #         Added command line parameters.
@REM #
@REM #         Added estimation tool with ratio.
@REM #
@REM #      2005/04/01 Version 1.6 -  Richard Macbeth, IBM/Tivoli Services
@REM #
@REM #
@REM #      2002/01/01 Version 1.0 -  Richard Macbeth, IBM/Tivoli Services
@REM #         Original Version
@REM #

@echo off

set THISFILE=%~f0
set THISARGS=%*
set ORIGDIR=%CD%
set PRCFGNXT=
set PRLOGNXT=
@setlocal


goto ENDUSAGE
@REM ####################### USAGE STATEMENT ##############################
:USAGE
if not "%ERRMSG%"=="" echo %ERRMSG%
echo.
echo USAGE:
echo.
echo   db2_tunings -s size [ -r ratio ] [ -e ] [ -I DB2Instance ] [ -db dbname ] 
echo.   
echo   db2_tunings -ibp ibmdefaultbp -lbp ldapbp [ -I DB2Instance ] [ -db dbname ] 
echo                  [ -? ]  prints usage message
echo                  [ -h ]  prints usage message
echo                  [ -help ]  prints usage message
echo.
echo     Options:
echo        -I DB2Instance  DB2 Instance name  (Defaults to DB2INSTANCE for user)
echo        -db dbname      DB name to update (Default=ldapdb2)
echo        -s size         Target memory usage in MB  (On Windows, this must be a 
echo                           predefined value, such as 256,512, 1024, 1536, 2048, 
echo                           3072, 4096)
echo        -r ratio        Bufferpool ratio, IBMDefaultBP/LdapBP (Default=3)
echo        -ibp ibmdefbp   Size of ibmdefaultbp bufferpool setting 
echo        -lbp ldapbp     Size of ldapbp bufferpool setting 
echo        -e              Print bufferpools options only.  If system memory 
echo        			      cannot be determined, size must be specified. 
echo        			      For Windows, -s is always required with -e.
echo.
echo   Note:  This command must be run from a DB2 command line processor (db2cmd)

goto END
@REM ################### END USAGE STATEMENT ##############################
:ENDUSAGE


@REM ##################### CONSTANTS STATEMENT #############################
set SHEAPTHRES=30000
set DBHEAP=3000
set CATALOGCACHE_SZ=64
set CHNGPGS_THRESH=60
set SORTHEAP=7138
set MAXLOCKS=80
set LOCKTIMEOUT=120
set LOCKLIST=400
set MINCOMMIT=1
set UTIL_HEAP_SZ=5000
set APPLHEAPSZ=2048
set STAT_HEAP_SZ=5120
@REM ## IOCLEANERS and IOSERVERS are now calculated based on the ldapbp value
@REM #NUM_IOCLEANERS=8
@REM #NUM_IOSERVERS=6
set DFT_PREFETCH_SZ=32
set MAXFILOP=384
set MAXAPPLS=100
set PCKCACHESZ=1440
@REM # If you are going to change the DFT_ENTENT_SZ you will also need to 
@REM #    remove the comment character from the "db2 update" command later on in 
@REM #    this script.    HINT: Search for EXTENT to find the command.
set DFT_EXTENT_SZ=32
set LOGFILSIZ=5000
set LOGPRIMARY=5
set LOGSECOND=60
@REM # If you are going to change the NEWLOGPATH you will also need to 
@REM #    remove the comment character from the "db2 update" command later on in 
@REM #    this script.    HINT: Search for NEWLOGPATH to find the command.
set NEWLOGPATH=C:\LOGDIR

@REM ################## END CONSTANTS STATEMENT ############################


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

:TBSPFAIL
   echo.
   echo Ensure you have the most recent DB2 fixpack installed or you will
   echo     not be able to disable file system caching.
   echo.
   set ERRMSG=ISST8124E: A DB2 alter tablespace command failed - %CMD%.
   db2 terminate 2>&1 > NUL
   set RC=24
   goto PRTEXIT

:DB2FAIL
   set ERRMSG=ISST8126E: A DB2 command returned an error - %CMD%.
   set RC=23
   goto PRTEXIT

:BPZERO
   set ERRMSG=ISST8127E: IBMDEFAULTBP and LDAPBP cannot be 0.  Please fix -ibp or -lbp.
   set RC=27
   goto PRTEXIT

:LOOPERR
   set ERRMSG=ISST8177E: No return label set in loop %LOOPNAME%.
   db2 terminate 2>&1 > NUL
   set RC=77
   goto PRTEXIT

@REM ################## END ERROR MESSAGES ################################
:ENDERRMG


goto ENDPRCFG
@REM ################ PRINT DB2 CFG SETTINGS ##############################
:PRTCFG
   echo. 
   echo The DB2 configuration parameters settings are as follows:
   echo. 
   @REM # Put each parameter on a separate line to make it easier to read.
   @REM # This doesn't work for Windows
   set DB2PARMS=%TEMP%\prtdb2parms.txt
   if exist "%DB2PARMS%" del /Q "%DB2PARMS%"
   echo BUFFPAGE> "%DB2PARMS%"
   echo DBHEAP>> "%DB2PARMS%"
   echo CATALOGCACHE_SZ>> "%DB2PARMS%"
   echo CHNGPGS_THRESH>> "%DB2PARMS%"
   echo SORTHEAP>> "%DB2PARMS%"
   echo MAXLOCKS>> "%DB2PARMS%"
   echo LOCKTIMEOUT>> "%DB2PARMS%"
   echo LOCKLIST>> "%DB2PARMS%"
   echo MINCOMMIT>> "%DB2PARMS%"
   echo UTIL_HEAP_SZ>> "%DB2PARMS%"
   echo APPLHEAPSZ>> "%DB2PARMS%"
   echo STAT_HEAP_SZ>> "%DB2PARMS%"
   echo NUM_IOCLEANERS>> "%DB2PARMS%"
   echo NUM_IOSERVERS>> "%DB2PARMS%"
   echo DFT_PREFETCH_SZ>> "%DB2PARMS%"
   echo MAXFILOP>> "%DB2PARMS%"
   echo MAXAPPLS>> "%DB2PARMS%"
   echo PCKCACHESZ>> "%DB2PARMS%"
   echo LOGFILSIZ>> "%DB2PARMS%"
   echo LOGPRIMARY>> "%DB2PARMS%"
   echo LOGSECOND>> "%DB2PARMS%"
   echo DFT_EXTENT_SZ>> "%DB2PARMS%"
   db2 get database configuration for %DBNAME% | findstr /i /G:"%DB2PARMS%"
   if exist "%DB2PARMS%" del /Q "%DB2PARMS%"
   if "%PRCFGNXT%"=="" set LOOPNAME=PRTCFG && goto LOOPERR
   goto %PRCFGNXT%
:ENDPRCFG
@REM ################ END PRINT DB2 CFG SETTINGS ##########################

goto ENDPRLOG
@REM ################ PRINT DB2 LOG SETTINGS ##############################
:PRTLOG
   echo. 
   echo The DB2 Log settings are as follows:
   echo. 
   @REM # Put each parameter on a separate line to make it easier to read.
   @REM # This doesn't work for Windows
   set DB2PARMS=%TEMP%\prtdb2parms.txt
   if exist "%DB2PARMS%" del /Q "%DB2PARMS%"
   echo LOGFILSIZ> "%DB2PARMS%"
   echo LOGPRIMARY>> "%DB2PARMS%"
   echo LOGSECOND>> "%DB2PARMS%"
   echo NEWLOGPATH>> "%DB2PARMS%"
   echo Path to log files>> "%DB2PARMS%"
   echo LOGSECOND >> "%DB2PARMS%"
   db2 get database configuration for %DBNAME% | findstr /i /G:"%DB2PARMS%"
   if exist "%DB2PARMS%" del /Q "%DB2PARMS%"
   if "%PRLOGNXT%"=="" set LOOPNAME=PRTLOG && goto LOOPERR
   goto %PRLOGNXT%
echo.
:ENDPRLOG
echo.
@REM ################ END PRINT DB2 LOG SETTINGS ##########################

:MAINPROG
set PARMS=0
set IPARM=1
set LPARM=2
set RPARM=4
set SPARM=8
set EPARM=32


@REM Parse command line arguments
:GETARG
set PARAM1=%~1
IF "%PARAM1%"=="" goto SETDEF
IF "%PARAM1%"=="-debug" goto SETTRC
IF "%PARAM1%"=="-I" goto SETINST
IF "%PARAM1%"=="-db" goto SETDB
IF "%PARAM1%"=="-e" goto SETESTIM
IF "%PARAM1%"=="-s" goto SETSIZE
IF "%PARAM1%"=="-ibp" goto SETIBP
IF "%PARAM1%"=="-lbp" goto SETLBP
IF "%PARAM1%"=="-r" goto SETRATIO
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
:SETSIZE
   set SIZE=%~2
   IF "%SIZE%"=="" goto USAGE
   set /A PARMS+=SPARM > NUL
   SHIFT && SHIFT
   goto GETARG
:SETRATIO
   set RATIO=%~2
   IF "%RATIO%"=="" goto USAGE
   set /A PARMS+=RPARM > NUL
   SHIFT && SHIFT
   goto GETARG
:SETLBP
   set LDAPBP=%~2
   IF "%LDAPBP%"=="" goto USAGE
   set /A PARMS+=LPARM > NUL
   SHIFT && SHIFT
   goto GETARG
:SETIBP
   set IBMDEFBP=%~2
   IF "%IBMDEFBP%"=="" goto USAGE
   set /A PARMS+=IPARM > NUL
   SHIFT && SHIFT
   goto GETARG
:SETESTIM
   set ESTIMATE=true
   set /A PARMS+=EPARM > NUL
   SHIFT
   goto GETARG

:SETDEF
   @REM # Setup Default variable settings
   if "%DB2INSTANCE%"=="" set DB2INSTANCE=ldapdb2
   if "%DBNAME%"=="" set DBNAME=ldapdb2
   if "%RATIO%"=="" set RATIO=3
   if "%DEBUG%"=="" set DEBUG=false
   if "%ESTIMATE%"=="" set ESTIMATE=false
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
echo      ESTIMATE=%ESTIMATE%
echo      RATIO=%RATIO%
echo      IBMDEFBP=%IBMDEFBP%
echo      LDAPBP=%LDAPBP%
echo. 
:ENDPRTST

@REM ###################### ERROR CHECKING ################################
:PROPCHECK

   @REM Verify that this is a DB2 command line processor window
   if "%DB2CLP%"=="" @echo off && goto NODB2CMD
   set TMPVAR=
   if not "%IBMDEFBP%"=="" set /A TMPVAR=IBMDEFBP*1
   if "%TMPVAR%"=="0" @echo off && goto BPZERO
   set TMPVAR=
   if not "%LDAPBP%"=="" set /A TMPVAR=LDAPBP*1
   if "%TMPVAR%"=="0" @echo off && goto BPZERO
   @REM # Verify that the correct command line parameters were specified.  The valid 
   @REM # required parameters are as follows:
   @REM #    -i and -l must be specified together (PARMS=3); no -s or -r
   @REM #       or
   @REM #    -s must be specified (PARMS=8); no -i or -l; -r is optional
   if "%PARMS%"=="3" goto GOODPARM
   if "%PARMS%"=="8" goto GOODPARM
   if "%PARMS%"=="12" goto GOODPARM
   if "%PARMS%"=="32" goto GOODPARM
   if "%PARMS%"=="36" goto GOODPARM
   if "%PARMS%"=="40" goto GOODPARM
   if "%PARMS%"=="44" goto GOODPARM
   goto USAGE
:GOODPARM
   
@REM ################## END ERROR CHECKING ################################
:ENDCHECK


@REM ################## ESTIMATE MEMORY USAGE #############################
if not %PARMS% GEQ 32 goto ENDCALC
   echo Memory Detected: Not Supported
   echo Recommended Memory Size: Not Supported (Use approx 1/2 total memory)
   echo Estimated Memory Size: %SIZE% MB  (User specified)

   set /A GUESSLBP=SIZE*32/(1+RATIO) > NUL
   set /A GUESSIBP=GUESSLBP*8*RATIO > NUL

   echo Recommended ibmdefaultbp setting: %GUESSIBP%  (assumes RATIO=%RATIO%)
   echo Recommended ldapbp setting: %GUESSLBP%  (assumes RATIO=%RATIO%)
   echo.
   goto PRTEXIT
@REM ################## END ESTIMATE MEMORY USAGE #########################
:ENDCALC

@REM # Ensure that DB2 has been started
if "%DEBUG%"=="true" db2start 2>&1 
if not "%DEBUG%"=="true" db2start 2>&1 > NUL

@REM ################## BUFFERPOOL TUNING #################################
@REM ### DB2 buffer pool tuning

if "%DEBUG%"=="true" db2 get instance
if "%DEBUG%"=="true" db2 list db directory
if "%DEBUG%"=="true" @echo on
db2 connect to %DBNAME% 
if not "%ERRORLEVEL%"=="0" @echo off && goto CONNFAIL
set ISDB2CONN=true 

@REM # Get the current buffer pool settings
echo.
echo The current buffer pool settings are as follows:
echo. 
set CMD=db2 select bpname,npages,pagesize from syscat.bufferpools
%CMD%
if not %ERRORLEVEL% LEQ 3 goto DB2FAIL

@REM # Tune the buffer pool
echo.
echo Updating the buffer pool settings.
echo.

@REM # 
@REM # IBMDEFBP = bufferpools for ibmdefaultbp
@REM # LDAPBP = bufferpools for ldapbp
@REM #
@REM # If IBMDEFBP and LDAPBP have been specified on the command line, then
@REM # those values will be used as is.  If SIZE was specified, then the 
@REM # appropriate bufferpool values must be calculated. 
@REM #
@REM # Numbers Explained:
@REM #    SIZE is the total amount of memory that should be used (in MB), in this 
@REM #    case.
@REM #
@REM #    MEM is the total amount of memory (in bytes) that the combined bufferpools 
@REM #    should use.  MEM=SIZE*1024*1024.
@REM #
@REM #    RATIO is the comparison between the sizes (in bytes) of IBMDefaultBP and 
@REM #    LdapBP, however, keep in  mind that the pagesize of LdapBP (32k) is 8 
@REM #    times larger than IBMDefaultBP (4k).  
@REM #
@REM #    The memory will be divided based on RATIO.  IBMDefaultBP will get RATIO
@REM #    times as much space as LdapBP.  For RATIO=3, LdapBP will be allocated
@REM #    X amount of space and IBMDefaultBP will be allocated 3X amount of space.
@REM #
@REM #       MEM =  SIZE * 1024 *1024
@REM #       MEM = (LDAPBP*PAGESIZE32k) + (IBMDEFBP*PAGESIZE4k)
@REM #       PAGESIZE32k = PAGESIZE4k*8
@REM #       PAGESIZE4k = 4096
@REM #       
@REM #       IBMDEFBP * PAGESIZE4k = RATIO * LDAPBP * PAGESIZE32k
@REM #       IBMDEFBP * PAGESIZE4k = RATIO * LDAPBP * PAGESIZE4k * 8
@REM #       IBMDEFBP = RATIO * LDAPBP * 8
@REM #
@REM #       MEM = (LDAPBP*PAGESIZE32k) + (IBMDEFBP*PAGESIZE4k)
@REM #       SIZE * 1024 * 1024 = (LDAPBP * PAGESIZE4k * 8) + (IBMDEFBP * PAGESIZE4k)
@REM #       SIZE * 1024 * 1024 / PAGESIZE4k = (LDAPBP * 8) + RATIO * LDAPBP * 8
@REM #       SIZE * 1024 * 1024 / 4096 / 8 = LDAPBP + RATIO * LDAPBP 
@REM #       SIZE * 32 = LDAPBP + RATIO * LDAPBP 
@REM #       SIZE * 32 = LDAPBP * (1 + RATIO)
@REM #       LDAPBP = SIZE * 32 / (1 + RATIO)
@REM #       IBMDEFBP = RATIO * LDAPBP * 8
@REM #

if "%LDAPBP%"=="" set /A LDAPBP=SIZE*32/(1+RATIO) > NUL
if "%IBMDEFBP%"=="" set /A IBMDEFBP=LDAPBP*8*RATIO > NUL

if "%DEBUG%"=="true" echo LDAPBP calculation = %LDAPBP%
if "%DEBUG%"=="true" echo IBMDEFBP calculation = %IBMDEFBP%

set CMD=db2 alter bufferpool ibmdefaultbp size %IBMDEFBP%
%CMD%
if not %ERRORLEVEL% LEQ 3 goto DB2FAIL

set CMD=db2 alter bufferpool ldapbp size %LDAPBP%
%CMD%
if not %ERRORLEVEL% LEQ 3 goto DB2FAIL

@REM ################## END BUFFERPOOL TUNING ##############################


@REM #################### GENERAL DB2 TUNING ###############################

@REM # Calculate NUM_IOCLEANERS and NUM_IOSERVERS based on the bufferpool values.
@REM # NUM_IOSERVERS should be set to approximately 1 for every 1500 LDAPBP.
@REM # NUM_IOCLEANERS should be 2 higher than NUM_IOSERVERS.
set /A NUM_IOSERVERS=LDAPBP/1500 > NUL
if not %NUM_IOSERVERS% GEQ 1 set NUM_IOSERVERS=1
set /A NUM_IOCLEANERS=NUM_IOSERVERS+2 > NUL

@REM # Print current db config settings 
if not "%DEBUG%"=="true" goto PRTRET1
set PRCFGNXT=PRTRET1
goto PRTCFG
:PRTRET1
set PRCFGNXT=

@REM ################ UPDATE DB2 CFG SETTINGS #############################
:UPCFG
   @REM # Tune the db config settings
   echo.
   echo Updating the DB2 config settings
   echo.
   
   db2 update dbm cfg using SHEAPTHRES %SHEAPTHRES%
   db2 update database configuration for %DBNAME% using SORTHEAP %SORTHEAP%
   db2 update database configuration for %DBNAME% using DBHEAP %DBHEAP%
   db2 update database configuration for %DBNAME% using CATALOGCACHE_SZ %CATALOGCACHE_SZ%
   db2 update database configuration for %DBNAME% using CHNGPGS_THRESH %CHNGPGS_THRESH%
   db2 update database configuration for %DBNAME% using MAXLOCKS %MAXLOCKS%
   db2 update database configuration for %DBNAME% using LOCKTIMEOUT %LOCKTIMEOUT%
   db2 update database configuration for %DBNAME% using LOCKLIST %LOCKLIST%
   db2 update database configuration for %DBNAME% using MINCOMMIT %MINCOMMIT%
   db2 update database configuration for %DBNAME% using UTIL_HEAP_SZ %UTIL_HEAP_SZ%
   db2 update database configuration for %DBNAME% using APPLHEAPSZ %APPLHEAPSZ%
   db2 update database configuration for %DBNAME% using STAT_HEAP_SZ %STAT_HEAP_SZ%
   db2 update database configuration for %DBNAME% using NUM_IOCLEANERS %NUM_IOCLEANERS%
   db2 update database configuration for %DBNAME% using NUM_IOSERVERS %NUM_IOSERVERS%
   db2 update database configuration for %DBNAME% using DFT_PREFETCH_SZ %DFT_PREFETCH_SZ%
   db2 update database configuration for %DBNAME% using MAXFILOP %MAXFILOP%
   db2 update database configuration for %DBNAME% using MAXAPPLS %MAXAPPLS%
   db2 update database configuration for %DBNAME% using PCKCACHESZ %PCKCACHESZ%
@REM   db2 update database configuration for %DBNAME% using DFT_EXTENT_SZ %DFT_EXTENT_SZ%

@REM ##################### FILE SYSTEM CACHING ##########################
@REM IF YOU ARE USING THE DEFAULTS TABESPACE NAMES (userspace1 and LDAPSPACE) then no changes 
@REM below are needed.  If not you will need to replace with the custom tablespace names your 
@REM are going to use.
@REM
set CMD=db2 alter tablespace userspace1 NO FILE SYSTEM CACHING
%CMD%
if not %ERRORLEVEL% LEQ 3 @echo off && goto TBSPFAIL
set CMD=db2 alter tablespace LDAPSPACE NO FILE SYSTEM CACHING
%CMD%
if not %ERRORLEVEL% LEQ 3 @echo off && goto TBSPFAIL
@REM ################ END UPDATE DB2 CFG SETTINGS #########################

if not "%DEBUG%"=="true" goto PRTRET2
@REM # Print new db config settings 
set PRCFGNXT=PRTRET2
goto PRTCFG
:PRTRET2
set PRCFGNXT=

set CMD=db2 terminate
%CMD%
if not %ERRORLEVEL% LEQ 3 @echo off && goto DB2FAIL

set CMD=db2 force applications all
%CMD%
if not %ERRORLEVEL% LEQ 3 @echo off && goto DB2FAIL

set CMD=db2stop
%CMD%
if not %ERRORLEVEL% LEQ 3 @echo off && goto DB2FAIL

set CMD=db2start
%CMD%
if not %ERRORLEVEL% LEQ 3 @echo off && goto DB2FAIL

@REM # Verify new settings

db2 connect to %DBNAME%
if not "%ERRORLEVEL%"=="0" @echo off && goto CONNFAIL
echo.
echo The new buffer pool settings are as follows:
echo.
db2 select bpname,npages,pagesize from syscat.bufferpools
set CMD=db2 terminate
%CMD%
if not %ERRORLEVEL% LEQ 3 @echo off && goto DB2FAIL

@REM ################ END UPDATE DB2 CFG SETTINGS #########################


@REM ################ DB2 TRANSACTION LOG SETTINGS ########################
@REM ### DB2 transaction log tuning

@REM # DB2 transaction log space is defined by the LOGFILSIZ, LOGPRIMARY, LOGSECOND,
@REM # and NEWLOGPATH parameters.  These parameters should be tuned to allow the 
@REM # transaction log to grow to its maximum required size.  In the normal use of 
@REM # the IBM Directory Server, the transaction log requirements are small.  Tools
@REM # that improve the performance of populating the directory server with a large 
@REM # number of users typically increase the transaction log requirements.  Here 
@REM # are examples:
@REM #
@REM # - The bulkload tools loads attribute tables for many entries in a single 
@REM #   load command. One table of particular interest is the group membership 
@REM #   table.  Bulkloading a large group of millions of users will increase the 
@REM #   transaction log requirements.
@REM #
@REM #   The transaction log requirements to load a 3 million user group is 
@REM #   around 300 MB.
@REM #   
@REM # - The Access Manager tuning guide scripts can update the ACL on a suffix such 
@REM #   that the ACL must be propagated to many other entries in the directory.  
@REM #   The IBM directory server combines all of the propagated updates into a 
@REM #   single committed transaction.
@REM #
@REM #   The transaction log requirements to propagate ACLs to a suffix with
@REM #   3 million Access Manager users is around 1.2 GB.
@REM #
@REM # Using the 1.2 GB requirement above, the transaction log requirements are 
@REM # approximately
@REM #
@REM # 1200000000 bytes / 3000000 users = 400 bytes per user
@REM # 
@REM # The DB2 defaults define a single transaction log buffer to be 2000 blocks of 
@REM # 4KB in size or 8000 KB.  The tunings in this file change this default to 5000
@REM # blocks or approximately 20 MB.
@REM #
@REM # The default number of primary log files is 3 and secondary log files is 2.  
@REM # This script sets the number primary log files to the default of 3 and adjusts 
@REM # the number of secondary log files as described below.
@REM #
@REM # With the settings made by this script, the primary log can grow to a maximum 
@REM # of (20MB * 3) or 60 MB.
@REM #
@REM # Instead of adjusting the number of primary logs to allow for additional 
@REM # growth, it is better to adjust the number of secondary logs, since the 
@REM # secondary log space is recovered when db2 is stopped and restarted 
@REM # (db2stop/db2start).
@REM #
@REM # Using the 400 bytes per user requirements from the ACL propagace case and 
@REM # the number of primary logs and size of the log file set by this script, the 
@REM # formula for increasing the transaction log secondary buffers is as follows:
@REM #
@REM # ( ( <num AM users> * 400 ) - 
@REM #           ( 20MB buffer size * 3 primary buffers ) ) / 20 MB buffer size
@REM #
@REM # For 3 million users, this approximates to the following:
@REM #
@REM # ( ( 3000000 * 400 ) - ( 20000000 * 3  ) ) / 20000000 = 57 secondary buffers
@REM #
@REM # The disk space requirements for this number of buffers is 1.2 MB
@REM #           20MB * ( 3 + 57 ) = 1.2 GB
@REM #
@REM # We are going to use 5000 file size 5 primary 60 secondary for 1.3 GB.  We
@REM # have 30 GB space for this.

echo.
echo Defining the transaction log size parameters to allow for the worst case of ACL
echo propagation.  The chosen setting will allow ACLs to propagate from a suffix to
echo up to 3 million users.  This setting can use up to 1.3GB
echo additional disk space in the DB2 instance owner home directory.
echo.
echo The number of log file size will be increased to %LOGFILSIZ%.
echo The number of primary log buffers will be increased to %LOGPRIMARY%.
echo The number of secondary log buffers will be increased to %LOGSECOND%.
echo. 
echo Adjust this setting (LOGSECOND) for more or less users.  Ensure the disk space
echo is available for whatever setting is used, since running out of disk space
echo for the transaction log can corrupt the database and require reloading of the
echo database.
echo.

@REM # Print current db config settings 
if not "%DEBUG%"=="true" goto LOGRET1
set PRLOGNXT=LOGRET1
goto PRTLOG
:LOGRET1
set PRLOGNXT=

echo. 
echo Updating the transaction log settings.
echo. 
db2 update database configuration for %DBNAME% using LOGFILSIZ %LOGFILSIZ%
db2 update database configuration for %DBNAME% using LOGPRIMARY %LOGPRIMARY%

@REM # Note: Update this parameter to increase or decrease the transaction log space.
db2 update database configuration for %DBNAME% using LOGSECOND %LOGSECOND%

@REM # Note: You should move the default location of the path of the log files
@REM # By default it is put where the db2 instance is found, for example 
@REM # /usr/opt/db2/log/LDAPDB2.  It is best if you move the location to another
@REM # directory, preferably on a different physical drive if possible. 
@REM db2 update db cfg for %DBNAME% using NEWLOGPATH "%NEWLOGPATH%" 

@REM # Restart db2 for changes to take effect
set CMD=db2stop
%CMD%
if not %ERRORLEVEL% LEQ 3 goto DB2FAIL

set CMD=db2start
%CMD%
if not %ERRORLEVEL% LEQ 3 goto DB2FAIL

if not "%DEBUG%"=="true" goto LOGRET2
@REM # Print current db config settings 
set PRLOGNXT=LOGRET2
goto PRTLOG
:LOGRET2
set PRLOGNXT=

echo.
echo Verify that the file system for the transaction logs is large enough to
echo accomodate the maximum growth.
echo.

set /A REQSPACE=LOGFILSIZ*4096*(LOGPRIMARY+LOGSECOND)/1024 > NUL

echo.
echo The log parameters allow the log files to grow to a maximum of %REQSPACE% KB. 
echo.
db2 get db cfg for %DBNAME% | findstr /C:"Path to log files" 
echo.
echo YOU MUST VERIFY THAT "Path to log files" SPECIFIES A LOCATION WITH
echo SUFFICIENT SPACE (%REQSPACE% KB)!!
echo.

@REM ############### END DB2 TRANSACTION LOG SETTINGS #####################


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

