PROG_DIR=$(cd $(dirname $0) && pwd)

sourcefile=$1
targetfile=`echo $1 | sed 's/javacore/threadstacks/'`
longstackfile=`echo $1 | sed 's/javacore/longstacks/'`

perl ${PROG_DIR}/j9dumpsummary.pl $sourcefile | sort --key=3 > $targetfile
awk '{if (length($0) > 1000) print}' $targetfile  > $longstackfile
${PROG_DIR}/stackcollapse-threadstack.sh $targetfile | /home/bachmann/src/FlameGraph/flamegraph.pl > ${targetfile}.svg
${PROG_DIR}/stackcollapse-threadstack.sh $longstackfile | /home/bachmann/src/FlameGraph/flamegraph.pl > ${longstackfile}.svg
