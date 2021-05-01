#! /bin/sh
if [ $# -lt 1 ]; then
echo usage $0 directory
exit
fi

PROG_DIR=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)
PROG_DIR=/home/bachmann/bin

cd $1
for webseald in `awk '$15=="/opt/pdweb/bin/webseald"{count[$1]++}END{for (i in count) print i}' pstack_logger_*.log`
do
  pstack_log=pstack_logger_${webseald}.log
  pstack_dir=pstacks_${webseald}
  if [ ! -d $pstack_dir ]; then
     mkdir $pstack_dir
  fi
  cd $pstack_dir
  awk -f ${PROG_DIR}/split_pstack_logger.awk ../$pstack_log
  ${PROG_DIR}/process_pstacks.sh .
  cd -
done

