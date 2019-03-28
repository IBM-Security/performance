#!/usr/local/bin/perl
#Author. Denis K. Sokolov 10/2010 IBM
#Project Manager. Nick Lloyd
#
#This script parses pdweb performance logs and creates a table
#that is passed to gnuplot, which graphs the data
#
#I/O:
#Input file: vhj log files specified by the user
#Output files: gnudata and gnuplot graphs
#
#vars:
#File contains output
#Time is pulled from data-less lines to be added to the output
#Data is pulled from data lines to be added to the output
#stat_num holds the indentifier of the current stat
#prev_nums holds the previous values of all stats so that differences can be calculated
#stat holds the value of the current stat
#temp holds data so it can be updated and transferred into prev_nums

$file = "Time\tActive\tTotal\t\'default active\'\t\'default\' total"; 	#organize gnudata columns
open (MYFILE, $ARGV[0]) || die("Cannot Open File");		#open input file

while (<MYFILE>) 			#while file is non-empty
{
 	s/\r[\n]*/\n/gm;  # now, an \r (Mac) or \r\n (Win) becomes \n (UNIX+)
 	if(/: (.*)/)	#$1 contains statistic
 	{
 		$data = $1;
		$file=$file."\t".$data;			#add relevant data to file
 	}
 	else		#no statistic (next block of stats)
 	{
 		if(/.*(..-..-..:..:..).*pdweb.threads.*/)
 		{
 			$time = $1;			#take down the time of next data set
 			$file = $file."\n".$time;	#add the time to the output file
 		}
 		elsif(/.*pdweb.(.*) stat.*/)
 		{
 			print "\nERROR: invalid log file: you have specified a $1 log file, need a threads log file\n\n";
 			exit 1;
 		}
 	}
}

close (MYFILE); 
print "$file";					#print output to file: gnudata
#open (MYFILE, '>plot_files/pdweb.threads/gnudata') || die("Cannot Open File");
#print MYFILE "$file";					#print output to file: gnudata
#close (MYFILE);

#plot output with gnuplot
#system("gnuplot/binary/gnuplot plot_files/pdweb.threads/threads_plot.dem");