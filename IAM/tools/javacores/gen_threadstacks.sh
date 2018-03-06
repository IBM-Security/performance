PROG_DIR=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)

sourcefile=$1
targetfile=`echo $1 | sed 's/javacore/threadstacks/'`
longstackfile=`echo $1 | sed 's/javacore/longstacks/'`

perl ${PROG_DIR}/j9dumpsummary.pl $sourcefile | sort --key=3 > $targetfile
awk '{if (length($0) > 1000) print}' $targetfile  > $longstackfile
