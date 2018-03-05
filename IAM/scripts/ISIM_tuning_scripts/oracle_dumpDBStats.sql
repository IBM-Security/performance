-- oracle_dumpDBStats.sql
-- Author: Casey Peel (cpeel@us.ibm.com)
-- Last Updated: 2009/06/25 0958 MDT
-- Summary:
--    Exports a file with contents of the v$sga and v$sysstat views.
-- Description:
--    This SQL file will export data from the v$sga and v$sysstat views
--    into a file.
--    The output is spooled to oracleDB.snapshot in the current directory.
-- Usage:
--    Log into SQL*Plus as sysdba (or another user with privileges to
--    query the v$sql view) and import this file using:
--       @oracle_dumpDBStats.sql

set pagesize 0;
set echo off;
set heading off;
set linesize 32767;
set trimspool on;
set feedback off;

spool oracleDB.snapshot
prompt v$sga:
select * from v$sga;
prompt
prompt v$sysstat:
select name, value from v$sysstat;
spool off;
