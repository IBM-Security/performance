#!/usr/local/bin/perl
#Author. Denis K. Sokolov and Connor Pokonry 10/2010 IBM
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

$stat_num = 0;			#keeps track of which stat is being parsed
@prev_nums = (0, 0, 0, 0, 0, 0);	#keeps previous stat values so that the difference can be calculated
@deltas = (0, 0, 0, 0, 0, 0);	#save calculated differences
$prev_time = 0;
$prev_interval = 0;

$file = "Time\tPass\tFail\tPwd Exp\tMax\tAvg\tTotal\tTput\tResp";	#organize gnudata columns
open (MYFILE, $ARGV[0]) || die("Cannot Open File");	#open input file

while (<MYFILE>) 			#while file is non-empty
{
 	s/\r[\n]*/\n/gm;  # now, an \r (Mac) or \r\n (Win) becomes \n (UNIX+)
 	if(/: (.*)/)	#$1 contains statistic
 	{
 		$stat = $1;
 		if($stat =~ /(.*):(.*):(.*)/)	#check if statistic has hours, minutes, and seconds
 		{
 			$hours = $1;
 			$minutes = $2;
 			$seconds = $3;
 			$data = 3600 * $hours + 60 * $minutes + $seconds;	#add seconds from hours, mins, and secs
 			if($stat_num != 3 && $stat_num != 4)
 			{
				$temp = $data;
				$data = $data - $prev_nums[$stat_num];	#get difference
				$prev_nums[$stat_num] = $temp;		#hold previous data
				$deltas[$stat_num] = $data;		#remember difference
			}
 		}
 		elsif($stat =~ /(.*):(.*)/)	#check if statistic has only minutes and seconds
 		{
 			$minutes = $1;
 			$seconds = $2;
 			$data = 60 * $minutes + $seconds;	#add seconds from minutes and seconds
 			if($stat_num != 3 && $stat_num != 4)
 			{
				$temp = $data;
				$data = $data - $prev_nums[$stat_num];	#get difference
				$prev_nums[$stat_num] = $temp;		#hold previous data
				$deltas[$stat_num] = $data;		#remember difference
			}
 		}
 		else				#in this case, data doesn't need to be manipulated
 		{
 			$data = $stat;
 			if($stat_num != 3 && $stat_num != 4)
 			{
				$temp = $data;
				$data = $data - $prev_nums[$stat_num];	#get difference
				$prev_nums[$stat_num] = $temp;		#hold previous data
				$deltas[$stat_num] = $data;		#remember difference
			}
 		}
 		$file = $file."\t".$data;	#add data to the table
		if($stat_num == 3 && $prev_nums[0] == 0)	# requests are 0 so far
		{
			$file = $file."\t0";		# if no requests, avg is missing from log
			$stat_num = 4;
		}
 		$stat_num = ($stat_num + 1) % 6;	#update to next stat
 	}
 	else
 	{
 		if(/.*(..-..-..:..:..).*pdweb.authn.*/)
 		{
 			$time = $1;			#take down the time of next data set
 			$time =~ /..-..-(..):(..):(..)/;
 			# calculate deltas, throughput, response time for interval
 			$hours = $1;
 			$minutes = $2;
 			$seconds = $3;
 			$since_midnight = 3600 * $hours + 60 * $minutes + $seconds;	#add seconds from hours, mins, and secs
 			if ($prev_interval > 0) {
 				if (($deltas[0] + $deltas[1]) > 0) {
 					$tput = sprintf("%.3f", ($deltas[0] + $deltas[1]) / $prev_interval);
 					$resp = sprintf("%.3f", $deltas[5] / ($deltas[0] + $deltas[1]));
 					$file = $file."\t".$tput."\t".$resp;
 				} else {
 					$file = $file."\t0\t0";
 				}
 			}
 			if ($prev_time > 0) {
 				if ($prev_interval == 0) {
  					$file = $file."\t0\t0";
				}
 				$prev_interval = $since_midnight - $prev_time;
 				if ($prev_interval < 0) {
 					$prev_interval += 3600 * 24;
 				}
 			}
 			$prev_time = $since_midnight;
 			$file = $file."\n".$time;	#add the time to the output file
 			$stat_num = 0;			#protects against bad index caclulation when new stats appear
 		}
 		elsif(/.*pdweb.(.*) stat.*/)
 		{
 			print "\nERROR: invalid log file: you have specified a $1 log file, need an authn log file\n\n";
 			exit 1;
 		}
 	}
}

close (MYFILE);
print "$file";
#open (MYFILE, '>'$ARGV[1]) || die("Cannot Open File");
#print MYFILE "$file";					#print output to file: gnudata
#close (MYFILE);

#plot output with gnuplot
#system("gnuplot/binary/gnuplot plot_files/pdweb.authn/authn_plot.dem");