#! /bin/sh
if [ $# -lt 1 ]; then
echo usage $0 directory
exit
fi

PROG_DIR=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)

for sourcefile in `ls $1/*pstack*`
do
   ${PROG_DIR}/get_threadstacks_from_pstack.sh $sourcefile
done

cat $1/threadstacks.*.txt | sort > $1/allstacks.txt
${PROG_DIR}/stackcollapse-threadstack.sh $1/allstacks.txt | ${PROG_DIR}/flamegraph.pl > allstacks.txt.svg
egrep -v 'pthread_cond_wait|pthread_cond_timedwait' $1/allstacks.txt > $1/allstacks_nowait.txt
${PROG_DIR}/stackcollapse-threadstack.sh $1/allstacks_nowait.txt | ${PROG_DIR}/flamegraph.pl > $1/allstacks_nowait.txt.svg
egrep -v 'mutex_lock|lock_wait' $1/allstacks_nowait.txt > $1/allstacks_nowait_nolock.txt
${PROG_DIR}/stackcollapse-threadstack.sh $1/allstacks_nowait_nolock.txt | ${PROG_DIR}/flamegraph.pl > $1/allstacks_nowait_nolock.txt.svg
