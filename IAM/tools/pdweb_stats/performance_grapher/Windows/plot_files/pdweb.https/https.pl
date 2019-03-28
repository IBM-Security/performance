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
#hours, minutes, and seconds hold time data
#temp holds data so it can be updated and transferred into prev_nums

$stat_num = 0;		#keeps track of which stat is being parsed
@prev_nums = (0, 0, 0, 0, 0, 0, 0);	#keeps previous stat values so that the difference can be calculated

#organize gnudata columns
$file = "Time\treqs\tmax-worker\ttotal-worker\tmax-webseal\ttotal-webseal";
open (MYFILE, $ARGV[0]) || die("Cannot Open File");	#open input file

while (<MYFILE>) 			#while file is non-empty
{
 	if(/: (.*)/)	#$1 contains statistic
 	{
 		$stat = $1;
 		if($stat =~ /(.*):(.*):(.*)/)	#check if statistic has hours, minutes, and seconds
 		{
 			$hours = $1;
 			$minutes = $2;
 			$seconds = $3;
 			$data = 3600 * $hours + 60 * $minutes + $seconds;	#add seconds from hours, mins, and secs
 			if($stat_num == 3 || $stat_num == 6)
 			{
				$temp = $data;
				$data = $data - $prev_nums[$stat_num];	#get difference
				$prev_nums[$stat_num] = $temp;		#hold previous data
			}
 		}
 		elsif($stat =~ /(.*):(.*)/)	#check if statistic has only minutes and seconds
 		{
 			$minutes = $1;
 			$seconds = $2;
 			$data = 60 * $minutes + $seconds;	#add seconds from minutes and seconds
 			if($stat_num == 3 || $stat_num == 6)
 			{
				$temp = $data;
				$data = $data - $prev_nums[$stat_num];	#get difference
				$prev_nums[$stat_num] = $temp;		#hold previous data
			}
 		}
 		else				#in this case, data doesn't need to be manipulated
 		{
 			$data = $stat;
 			if($stat_num == 0 || $stat_num == 3 || $stat_num == 6)
 			{
				$temp = $data;
				$data = $data - $prev_nums[$stat_num];	#get difference
				$prev_nums[$stat_num] = $temp;		#hold previous data
			}
 		}
 		$file = $file."\t".$data;	#add data to the table
 		$stat_num = ($stat_num + 1) % 7;	#update to next stat
 	}
 	else
 	{
 		if(/.*(..-..-..:..:..).*pdweb.https.*/)
 		{
 			$time = $1;			#take down the time of next data set
 			$file = $file."\n".$time;	#add the time to the output file
 			$stat_num = 0;			#protects against bad index caclulation when new stats appear
 		}
 		elsif(/.*pdweb.(.*) stat.*/)
 		{
 			print "\nERROR: invalid log file: you have specified a $1 log file, need an https log file\n\n";
 			exit 1;
 		}
 	}
}

close (MYFILE); 
open (MYFILE, '>plot_files/pdweb.https/gnudata') || die("Cannot Open File");
print MYFILE "$file";					#print output to file: gnudata
close (MYFILE);

#plot output with gnuplot
system("gnuplot/binary/gnuplot plot_files/pdweb.https/https_plot.dem");