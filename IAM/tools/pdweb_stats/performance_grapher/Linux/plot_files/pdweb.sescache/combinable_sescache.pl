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

$max = 0;	#max keeps track of maximum stat for interval measuring

$stat_num = 0;			#keeps track of which stat is being parsed
@prev_nums = (0, 0, 0, 0, 0, 0, 0);	#keeps previous stat values so that the difference can be calculated

$file = "Time\tHit\tMiss\tAdd\tDel\tInactive\tLifetime\tLRU expired"; 	#organize gnudata columns
open (MYFILE, $ARGV[0]) || die("Cannot Open File");		#open input file

while (<MYFILE>) 			#while file is non-empty
{
 	if(/: (.*)/)	#$1 contains statistic
 	{
 		$data = $1;
 		$temp = $data;
		$data = $data - $prev_nums[$stat_num];	#get difference
		$prev_nums[$stat_num] = $temp;		#hold previous data
		
		if($stat_num == $ARGV[2])	#help calculate interval
 		{
 			if($data > $max)
 			{
				$max = $data;
			}
 		}
 		
		$file=$file."\t".$data;			#add relevant data to file
		$stat_num = ($stat_num + 1) % 7;	#update to next stat
 	}
 	else		#no statistic (next block of stats)
 	{
 		if(/.*(..-..-..:..:..).*pdweb.sescache.*/)
 		{
 			$time = $1;			#take down the time of next data set
 			$file = $file."\n".$time;	#add the time to the output file
 		}
 		elsif(/.*pdweb.(.*) stat.*/)
 		{
 			print "\nERROR: invalid log file: you have specified a $1 log file, need a sescache log file\n\n";
 			exit 1;
 		}
 	}
}

close (MYFILE); 
if($ARGV[1] eq "g1")
{
	open (MYFILE, '>gnudata_1') || die("Cannot Open File");
}
else
{
	open (MYFILE, '>gnudata_2') || die("Cannot Open File");
}
print MYFILE "$file";		#print output to file: gnudata_1 or gnudata_2
close (MYFILE);

if($ARGV[2] != -1)		#pass interval to combiner script through separate file
{
	$interval = $max/10;
	open (MYFILE, '>interval') || die("Cannot Open File");
	print MYFILE "$interval";
}