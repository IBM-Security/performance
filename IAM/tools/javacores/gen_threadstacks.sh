PROG_DIR=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)

sourcefile=basename $1
sourcedir=dirname $1
targetfile=`echo $1 | sed 's/javacore/threadstacks/'`
longstackfile=`echo $1 | sed 's/javacore/longstacks/'`

perl ${PROG_DIR}/j9dumpsummary.pl $sourcedir/$sourcefile | sort --key=3 > $sourcedir/$targetfile
awk '{if (length($0) > 1000) print}' $sourcedir/$targetfile  > $sourcedir/$longstackfile
${PROG_DIR}/stackcollapse-threadstack.sh $sourcedir/$targetfile | ${PROG_DIR}/flamegraph.pl > $sourcedir/${targetfile}.svg
${PROG_DIR}/stackcollapse-threadstack.sh $sourcedir/$longstackfile | ${PROG_DIR}/flamegraph.pl > $sourcedir/${longstackfile}.svg
