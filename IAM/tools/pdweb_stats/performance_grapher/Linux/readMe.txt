This performance grapher tool was created by Denis Sokolov, Connor R. Pokorny and Nick Lloyd.
It was ported to Linux by Dave Bachmann.

The tool takes pdweb stats log files and graphs the data in them using gnuplot
to make png files. It takes the log files in the specified logs folder and parses them to
make data files for gnuplot and then plots these data files using gnuplot. The
graphs are all organized by statistic in the graphs folder of the specified output directory. 
To run the tool use the generate_graphs_from_statistics.sh shell script.
Specify at minumum the directory containing pdweb statistics log files, and optionally
an output directory.  If no output directory is specified, the data and graphs directories will
be created in the input directory.  Individual graphs will be created in the graphs subdirectory
and a summary html file that sources all the graphs will be created in the output directory.

The script looks for each type of statistic supported (pdweb.authn, pdweb.authz, etc) and
processes all files containing those statistics.  No assumptions are made about file naming.
For each type of statistics, if there are any files containing that statistic, all the lines
for that statistic will be grepped out and piped to the corresponding perl script.
The perl script converts pdweb statistics to gnuplot input files that are placed in the
data subdirectory of the output directory.  The script then calls the appropriate gnuplot
script to generate a graph of those statistics and all the graphs are generated in the
graphs subdirectory of the output directory.

To take full advantage of this tool, the customer should turn on pdweb stats for a day
with an interval of about five minutes. The customer can either activate all of the stats
or just the ones they are worried about. Then, they should send in the log files that
have accumulated, which should be put into a single folder that is passed to this tool and 
then the tool will make graphs from those log files.

pdweb stats that are covered: pdweb.authn, pdweb.authz, pdweb.certcallbackcache,
		    	      pdweb.doccache, pdweb.drains, pdweb.http, pdweb.https,
			      pdweb.jct.#, pdweb.jmt, pdweb.sescache, pdweb.threads,
			      pdweb.usersessidcache, pdweb.vhj.#

requirements for the tool: gnuplot, perl, bash (tested on Linux)

Parts of the tool:
-plot_files: contains the script files that parse the log files and graph the data.
	     These are organized by statistic. Each statistic has a perl script
	     file (.pl) and gnuplot driver script file (.dem).

-generate_graphs_from_statistics.sh: bash shell script that calls all the perl scripts one by one if the
		  corresponding log file exists

-readMe.txt: this file.