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
#fileNum determines which vhj log file is being parsed
#Time is pulled from data-less lines to be added to the output
#Data is pulled from data lines to be added to the output
#stat_num holds the indentifier of the current stat
#prev_nums holds the previous values of all stats so that differences can be calculated
#lines holds the lines of the inputs
#junct holds the junction name used for naming the output files
#stat holds the value of the current stat
#hours, minutes, and seconds hold time data
#temp holds data so it can be updated and transferred into prev_nums

$stat_num = 0;			#keeps track of which stat is being parsed
@prev_nums = (0, 0, 0, 0);	#keeps previous stat values so that the difference can be calculated

open (MYFILE, $ARGV[1]) || die("Cannot Open File");	#open input file
@lines = <MYFILE>;
if($lines[1] =~ /\[(.*)\]/)
{
	$junct = $1;		#get junction name
	if($junct eq "")
	{
		$junct = "root_vhj";		#handle blank jct
	}
	else
	{
		$junct =~ s/\//\_slash\_/;	#replace slashes to avoid invalid directory creation
	}
}

$file = "Time\treqs\tmax\taverage\ttotal"; #organize gnudata columns

foreach(@lines) 			#while file is non-empty
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
			if($stat_num == 3)
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
			if($stat_num == 3)
			{
				$temp = $data;
				$data = $data - $prev_nums[$stat_num];	#get difference
				$prev_nums[$stat_num] = $temp;		#hold previous data
			}
		}
		else				#in this case, data doesn't need to be manipulated
		{
			$data = $stat;
			if($stat_num == 3 || $stat_num == 0)
			{
				$temp = $data;
				$data = $data - $prev_nums[$stat_num];	#get difference
				$prev_nums[$stat_num] = $temp;		#hold previous data
			}
		}
		$file = $file."\t".$data;		#add data to the table
		$stat_num = ($stat_num + 1) % 4;	#update to next stat
	}
	else
	{
		if(/.*(..-..-..:..:..).*pdweb.vhj.*/)
 		{
 			$time = $1;			#take down the time of next data set
 			$file = $file."\n".$time;	#add the time to the output file
 			$stat_num = 0;			#protects against bad index caclulation when new stats appear
 		}
 		elsif(/.*pdweb.(.*) stat.*/)
 		{
 			print "\nERROR: invalid log file: you have specified a $1 log file, need a vhj log file\n\n";
 			exit 1;
 		}
	}
}

close (MYFILE); 
open (MYFILE, '>plot_files/pdweb.vhj.#/gnudata') || die("Cannot Open File");
print MYFILE "$file";				#print output to file: gnudata
close (MYFILE);
	
#create directories for each junction
system("mkdir $ARGV[0]\\pdweb_vhj\\$junct");

#create gnuplot file to plot the data
$filename1 = $junct . "/" . $junct . "_vhj_plot_reqs.png";
$filename2 = $junct . "/" . $junct . "_vhj_plot_max_time.png";
$filename3 = $junct . "/" . $junct . "_vhj_plot_average_time.png";
$filename4 = $junct . "/" . $junct . "_vhj_plot_total_time.png";
open (MYFILE, '>plot_files/pdweb.vhj.#/vhj_plot.dem');
print MYFILE "#Author. Denis K. Sokolov and Connor R. Pokorny 7/2010 IBM
#This is a gnu script that will plot the performance stats on gnuplot
#using the output of vhj.pl (a perl script) as input (i.e. gnudata)

#set scaling
set autoscale
set xtic rotate by -90
set xdata time
set timefmt \"%m-%d-%H:%M:%S\"
set format x \"%m-%d-%H:%M:%S\"
set ytic auto
set mxtics
set mytics
set grid

#label axes, title, and legend
set xlabel \"Time\"  
set ylabel \"Reqs\"
set title \"VHJ Performance: $junct\"
set key rmargin

#sets reqs output file and plots reqs data to it
set terminal png enhanced size 1280,1024
set output \"$ARGV[0]/pdweb_vhj/$filename1\"
plot 'plot_files/pdweb.vhj.#/gnudata' every ::2 using 1:2 index 0 with lines linewidth 2 linetype rgb \"blue\" title \"reqs\"

#change ylabel for seconds data
set ylabel \"Performance (seconds)\"

#plots max and average data on respective graphs
set output \"$ARGV[0]/pdweb_vhj/$filename2\"
plot 'plot_files/pdweb.vhj.#/gnudata' every ::2 using 1:3 index 0 with lines linewidth 2 linetype rgb \"blue\" title \"max\"

set output \"$ARGV[0]/pdweb_vhj/$filename3\"
plot 'plot_files/pdweb.vhj.#/gnudata' every ::2 using 1:4 index 0 with lines linewidth 2 linetype rgb \"blue\" title \"average\"

#plots total time data
set output \"$ARGV[0]/pdweb_vhj/$filename4\"
plot 'plot_files/pdweb.vhj.#/gnudata' every ::2 using 1:5 index 0 with lines linewidth 2 linetype rgb \"blue\" title \"total\"";

close (MYFILE);

#plot output with gnuplot
system("gnuplot/binary/gnuplot plot_files/pdweb.vhj.#/vhj_plot.dem");