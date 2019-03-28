#!/usr/local/bin/perl
#Author. Denis K. Sokolov 10/2010 IBM
#
#This is a driver for performance data graphing perl scripts
#
#I/O:
#Input: performance execution options, log files containing performance data
#Output files: folders containing specified gnuplot graphs
#
#vars:
#months, weekDays, localtime vars, and year help calculate the current time
#theTimeFolder holds the unique output folder name for the output graphs

#calculate current time
@months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
@weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
$year = 1900 + $yearOffset;

$theTimeFolder = "$weekDays[$dayOfWeek]_$months[$month]\-$dayOfMonth\-$year\_$hour\H$minute\M$second\S_graphs";	#construct folder name

system("rename current_output_graphs output_graphs_$theTimeFolder");
system("mkdir current_output_graphs");