PROG_DIR=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)

sourcefile=$1
targetfile=`echo $1 | sed 's/pstack/threadstacks/'`
awk -f ${PROG_DIR}/pstacksum.awk $sourcefile | sort --key=3 > $targetfile
