#!/bin/bash
# generate_graphs_from_statistics.sh
# Dave Bachmann 3/2019 IBM
#
# Convert pdweb statistics logs into graphs with gnuplot

if [ $# -lt 1 ]
then
  echo usage $0 logs_directory [output_directory]
  echo If output_directory is not specified, graphs with be generated in the input_directory
  exit
fi

input_dir=$1

if [ $# -eq 2 ]
then
  output_dir=$2
else
  output_dir=$input_dir
fi

if [ ! -d $input_dir ]
then
  echo $input_dir not found
  exit
fi
 
if [ ! -d $output_dir/data ]
then
  mkdir -p $output_dir/data $output_dir/graphs
fi


if [ ! -d $output_dir ]
then
  echo Unable to create $output_dir
  exit
fi
 
echo Beginning processing logs in $input_dir on `date`

# execute all perl scripts to parse the logs, make data files, and plots if logs exists

for stat in `ls plot_files | awk '{n=split($1,comps,".");print comps[2]}'`
do
  # checking for logs of type ${stat} in $input_dir
  # the key to this is that all lines include the name of the statistic (e.g. pdweb.http) in them delimited by spaces
  # special case jct.# and vhj.#
  if [ "$stat" == "jct" ]
  then
    pattern=" pdweb.jct.[0-9]* "
    scriptdir=pdweb.jct.#
  elif [ "$stat" == "vhj" ]
  then
    pattern=" pdweb.vhj.[0-9]* "
    scriptdir=pdweb.vhj.#
  else
    pattern=" pdweb.${stat} "
    scriptdir=pdweb.${stat}
  fi
  grep -q "${pattern}" $input_dir/* 2>/dev/null 
  if [ $? -eq 0 ]
  then
    # found logs of type ${stat}, processing
    # first transform pdweb statistics to columnar datafile
    datafile=${output_dir}/data/${stat}.data
    cat $input_dir/* | grep "${pattern}" | perl plot_files/${scriptdir}/${stat}.pl - > ${datafile}
    # second plot data as a set of line graphs
    outputfile=${output_dir}/graphs/${stat}
    gnuplot -e "datafile='${datafile}'; outputfile='${outputfile}'; " plot_files/${scriptdir}/${stat}_plot.dem  
  fi
done

# generate summary report

cp report_generator/graphs.css ${output_dir}/
summary=${output_dir}/graphs.html
cp report_generator/report_head.html ${summary}
ls ${output_dir}/graphs | awk -f report_generator/gen_topnav.awk >> ${summary}
ls ${output_dir}/graphs | awk -f report_generator/gen_sections.awk >> ${summary}
date +%Y-%m-%d| awk -f report_generator/gen_footer.awk >> ${summary}

# if exists logs/jct_1.log perl plot_files/pdweb.jct.#/jct.pl
# if exists logs/vhj_1.log perl plot_files/pdweb.vhj.#/vhj.pl

echo Completed processing on `date`
echo Graphs are in $output_dir/graphs
echo Summary report is ${summary}