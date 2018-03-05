-- oracle_exportDDL.sql
-- Author: Casey Peel (cpeel@us.ibm.com)
-- Last Updated: 2009/06/08 1722 MDT
-- Summary:
--    Exports a DDL file of the tables, indexes, and views owned by the
--    executing user.
-- Description:
--    This SQL file will use the DBMS_METADATA package to export the
--    table, index, and views DDL belonging to the executing user.
--    The output is spooled to tables.ddl in the current directory.
-- Usage:
--    Log into SQL*Plus as the ITIM User and import this file using:
--       @oracle_exportDDL.sql

set heading off;
set echo off;
set linesize 32767;
set long 90000;
set trimspool on;
set feedback off;

spool tables.ddl;
select '-- Tables' from dual;
select dbms_metadata.get_ddl('TABLE', u.table_name) from user_tables u;
select '-- Indexes' from dual;
select dbms_metadata.get_ddl('INDEX', u.index_name) from user_indexes u;
select '-- Views' from dual;
select dbms_metadata.get_ddl('VIEW', u.view_name) from user_views u;
spool off;

