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
