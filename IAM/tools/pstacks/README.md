# IBM Security Performance

## Identity and Access Management

### Useful tools

#### pstack analysis tools

This directory contains scripts for analyzing pstacks from current versions of Linux's pstack command in the gdb package.
Other versions may require slight changes to pstacksum.awk.

process_pstacks.sh will look for all files named *pstack* in the specified directory and process them with get_threadstacks_from_pstack.sh

get_threadstacks_from_pstack.sh will process the specified javacore using the pstacksum.awk script

pstacksum.awk takes the thread stacks in the specified file and flattens them with each thread on its own line.

For each XXpstackYY file in the directory, a corresponding file named XXthreadstacksYY with all the flattened stacks from the pstack is produced, sorted to group common stacks together.

These files are most usefully viewed using a text editor with word wrap turned off.

Once you find interesting patterns in the stacks, you can use grep -c to count occurrences of the patterns, or grep and grep -v to split the stacks into subsets.

The scripts also generate [Flame Graphs](http://www.brendangregg.com/FlameGraphs/cpuflamegraphs.html) of each of the threadstacks as well as 
each of the longstacks file and one of the all_longstacks file.  Flame Graphs are a very useful way of getting the big picture first so you know
where your threads are spending most of the time and thus what to focus your investigations on.  You should update the copy of *flamegraph.pl*
here with the latest from [the FlameGraph github repository](https://github.com/brendangregg/FlameGraph) before running these scripts.

