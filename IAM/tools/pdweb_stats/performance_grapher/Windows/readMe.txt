This performance grapher tool was created by Denis Sokolov 08/10/10 IBM.
Direct any questions about it to dksokolov@gmail.com

The tool takes pdweb stats log files and graphs the data in them using gnuplot
to make png files. It takes the log files in the logs folder and parses them to
make data files for gnuplot and then plots these data files using gnuplot. The
graphs are all organized by statistic in the output_graphs folder. To run the tool
use the perl_driver.bat windows batch file. It calls all the perl scripts that parse
the log files if the logs are present and those in turn call the gnuplot scripts
that graph the data. Before it does its main task, the tool erases all output graphs
that were in the output_graphs subdirectories at that time, so those should be backed up
to keep them. Note: the tool does not delete the subdirectories themselves, including
the pdweb.jct and pdweb.vhj subdirectories involving junction names.

To take full advantage of this tool, the customer should turn on pdweb stats for a day
with an interval of about five minutes. The customer can either activate all of the stats
or just the ones they are worried about. Then, they should send in the log files that
have accumulated, which should be put into the logs folder of this tool and then the
tool will make graphs from those log files.

pdweb stats that are covered: pdweb.authn, pdweb.authz, pdweb.certcallbackcache,
		    	      pdweb.doccache, pdweb.drains, pdweb.http, pdweb.https,
			      pdweb.jct.#, pdweb.jmt, pdweb.sescache, pdweb.threads,
			      pdweb.usersessidcache, pdweb.vhj.#

requirements for the tool: gnuplot, perl, windows OS

Parts of the tool:
-gnuplot folder: contains gnuplot files necessary to run gnuplot instructions

-logs folder: contains the input pdweb log files. All log files must be named correctly
	      in order for the tool to operate on them. All log files that are
	      in the folder will be operated on so dont have any unwanted log files
	      lingering from one use of the tool to another.

-output_graphs folder:  contains the graphs of the stats over the time that they were on
		        (target time: 1 day) in png format. These graphs are organized by
			stat type (e.g. pdweb.authn has its own folder). For pdweb.jct and
			pdweb.vhj there are further subfolders created for each junction
			during execution. Note: these subdirectories do not get deleted
			when the tool cleans out output_graphs in the beginning.

-plot_files: contains the script files that parse the log files and graph the data.
	     These are also organized by statistic. Each statistic has a perl script
	     file (.pl), a gnuplot script file (.dem), and gnuplot driver script file (.dem),
	     and a data file (gnudata).

-perl_driver.bat: windows batch file that calls all the perl scripts one by one if the
		  corresponding log file exists

-test_del.bat: windows batch file used mainly for testing. Deletes all gnudata file and
	       empties subdirectories in output_graphs.

-readMe.txt: this file.