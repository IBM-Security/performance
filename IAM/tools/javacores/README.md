# IBM Security Performance

## Identity and Access Management

### Useful tools

#### Javacore analysis tools

This directory contains scripts for analyzing javacores from recent versions of the jvm.
Different versions my require slight changes to j9dumpsummary.pl

process_javacores.sh will look for all files named javacore* in the specified directory and process them with gen_threadstacks.sh

gen_threadstacks.sh will process the specified javacore using the j9dumpsummary.pl script

j9dumpsummary.pl takes the thread stacks in the specified javacore and flattens them with each thread on its own line.

For each javacoreXXX file in the directory, a corresponding file named threadstacksXXX with all the flattened stacks from the javacore, and a file named longstacksXXX with only the flattened stacks that are longer than 1000 characters long.
There is also a file named all_longstacks.txt created with all the long stacks from the longstacks files, sorted to group common stacks together.

These files are most usefully viewed using a text editor with word wrap turned off.

Once you find interesting patterns in the stacks, you can use grep -c to count occurrences of the patterns, or grep and grep -v to split the stacks into subsets.

The scripts also generate [Flame Graphs](http://www.brendangregg.com/FlameGraphs/cpuflamegraphs.html) of each of the threadstacks as well as 
each of the longstacks file and one of the all_longstacks file.  Flame Graphs are a very useful way of getting the big picture first so you know
where your threads are spending most of the time and thus what to focus your investigations on.  You should update the copy of [[flamegraph.pl]] 
here with the latest from [the FlameGraph github repository](https://github.com/brendangregg/FlameGraph) before running these scripts.

An example can be seen at [[examples/all_longstacks_rsa.txt.svg]] - click on one of the higher boxes to zoom in and click on one of the lower boxes
to zoom out.  See the [Flame Graphs](http://www.brendangregg.com/FlameGraphs/cpuflamegraphs.html) page for more details on using Flame Graphs.