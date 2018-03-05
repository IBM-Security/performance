REM perftune_queues_cear.bat
REM Author: Casey Peel (cpeel@us.ibm.com)
REM Last UpdateD: 2006/02/23 0816 CST
REM Desription:
REM   Script to clear the MQ queues from a ITIM WAS server.
REM Usage:
REM   This script should be run in the same directory as the
REM   perftune_queues_clear.mqs file

set QUEUEMANAGER=WAS_timperf04_jmsserver

runmqsc %QUEUEMANAGER% < perftune_queues_clear.mqs
