-- oracle_dumpSQLStats.sql
-- Author: Casey Peel (cpeel@us.ibm.com)
-- Last Updated: 2009/06/25 1524 MDT
-- Summary:
--    Exports a file with SQL statistics from the v$sql performance view.
-- Description:
--    This SQL file will pull data from the v$sql view into a file
--    formatted in a way that it is parseable by the
--    perfanalyze_dynamicsql.pl script.
--    The output is spooled to dynamicsql.snapshot in the current directory.
-- Usage:
--    Log into SQL*Plus as sysdba (or another user with privileges to
--    query the v$sql view) and import this file using:
--       @oracle_dumpSQLStats.sql

COLUMN statement FOLD_AFTER;
COLUMN numExec FOLD_AFTER;
COLUMN totalExecTime FOLD_AFTER;
COLUMN rowsRead FOLD_AFTER;
COLUMN rowsWritten FOLD_AFTER;

set pagesize 0;
set echo off;
set heading off;
set linesize 32767;
set trimspool on;
set feedback off;

spool dynamicsql.snapshot
select ' Database name = ORACLE' from dual;
prompt
select
   concat(' Number of executions = ',executions) as numExec,
   concat(' Total execution time = ',cpu_time/1000000) as totalExecTime,
   concat(' Rows read = ', rows_processed) as rowsRead,
   concat(' Rows written = ', rows_processed) as rowsWritten,
   concat(' Statement text = ',sql_text) as statement
from v$sql
order by executions desc;
spool off;
