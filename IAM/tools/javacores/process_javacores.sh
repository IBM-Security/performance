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

awk '{print $NF}' longstack* | sort > all_longstacks.txt
