#! /bin/sh
if [ $# -lt 1 ]; then
   echo usage $0 directory
   exit
fi

PROG_DIR=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)

for sourcefile in `ls $1/javacore*.txt`
do
   ${PROG_DIR}/gen_threadstacks.sh $sourcefile
done

awk '{print $NF}' $1/longstack*.txt | sort > $1/all_longstacks.txt
${PROG_DIR}/stackcollapse-threadstack.sh $1/all_longstacks.txt | ${PROG_DIR}/flamegraph.pl > $1/all_longstacks.txt.svg
