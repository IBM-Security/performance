#! /bin/sh
if [ $# -lt 1 ]; then
   echo usage $0 directory
   exit
fi

filelist=`ls $1/javacore*.txt`

if [ "X${filelist}" == "X" ]; then
   echo no javacores found in $1
   exit
fi

PROG_DIR=$(cd $(dirname $0) && pwd)

cd $1

for sourcefile in `ls javacore*.txt`
do
   ${PROG_DIR}/gen_threadstacks.sh $sourcefile
done

awk '{print $NF}' longstack*.txt | sort > all_longstacks.txt
${PROG_DIR}/stackcollapse-threadstack.sh all_longstacks.txt | ${PROG_DIR}/flamegraph.pl > all_longstacks.txt.svg
