-- oracle_dumpDBCfg.sql
-- Author: Casey Peel (cpeel@us.ibm.com)
-- Last Updated: 2009/06/25 0958 MDT
-- Summary:
--    Exports a file with the contents of the v$parameter view.
-- Description:
--    This SQL file will export data from the v$paraemter view
--    into a file.
--    The output is spooled to oracleDB.cfg in the current directory.
-- Usage:
--    Log into SQL*Plus as sysdba (or another user with privileges to
--    query the v$sql view) and import this file using:
--       @oracle_dumpDBCfg.sql

set pagesize 0;
set echo off;
set heading off;
set linesize 32767;
set trimspool on;
set feedback off;

spool oracleDB.cfg
prompt v$parameter:
select name, value from v$parameter order by name;
spool off;
