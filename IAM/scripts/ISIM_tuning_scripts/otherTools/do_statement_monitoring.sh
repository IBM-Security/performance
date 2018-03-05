#!/bin/ksh

# Script to do statement monitoring

# This script writes the monitor output to the current directory

if [ `uname` = "Linux" ];then
# define a print function, since Linux doesn't seem to have one
print(){    
echo "$@"
}
fi

db2 connect to itim

db2 list tables | grep EXPLAIN_ >$0.tmp
if [ "X`cat $0.tmp`" = "X" ];then

	print Performing one time setup ...
	db2 -tf $HOME/sqllib/misc/EXPLAIN.DDL

fi
rm $0.tmp

# Monitoring statements

db2 "drop event monitor dstatement" >/dev/null
# db2 "create event monitor dstatement for statements write to file $PWD"
print db2 \"create event monitor dstatement for statements write to file \'$PWD\'\" >$0.tmp
. $0.tmp
rm $0.tmp

db2 "set event monitor dstatement state 1"

print Do experiment to be monitored now.  Press enter to stop monitoring.
read dummyvar

db2 "set event monitor dstatement state 0"      
db2evmon -path $PWD >$PWD/dstate.out

# Maybe use mon.awk to further process the output
# awk -f mon.awk $PWD/dstate.out

db2 "drop event monitor dstatement"

db2 terminate

# Use proc_stmt_mon_output.awk to further process the output
awk -f proc_stmt_mon_output.awk $PWD/dstate.out >$PWD/mon.out
sort -n +1 mon.out >mon.sorted

echo "Full output in dstate.out, summary in mon.out, sorted by time in mon.sorted"
