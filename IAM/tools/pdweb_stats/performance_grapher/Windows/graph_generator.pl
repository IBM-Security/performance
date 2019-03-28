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
#i is a loop iterator
#output_folder holds altered name of output (if applicable)

#calculate current time
@months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
@weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
$year = 1900 + $yearOffset;

$theTimeFolder = "$weekDays[$dayOfWeek]_$months[$month]\-$dayOfMonth\-$year\_$hour\H$minute\M$second\S_graphs";	#construct folder name

$i = 0;

while( ($i < ($#ARGV + 1)) && ($file_change == 0) )		#if the user specifies an output folder, then it needs to be changed right away
{
	if($ARGV[$i] eq "-out" || $ARGV[$i] eq "-o")
	{
		$outputFolder = $ARGV[$i + 1]."_".$theTimeFolder;
		$theTimeFolder = $outputFolder;
		system("mkdir $theTimeFolder");	#makes output folder from user specification
		$file_change = 1;
	}
	$i++;
}
if($file_change == 0)
{
	system("mkdir $theTimeFolder");	#if the user did not specify an output folder, then create the default output folder
}

$i = 0;

while($i < $#ARGV + 1)
{
	if( ($ARGV[$i] eq "-an")  || ($ARGV[$i] eq "-authn") )				#authn case
	{
		print "Plotting pdweb.authn...\n";
		system("mkdir $theTimeFolder\\pdweb_authn");
		system("perl plot_files\\pdweb.authn\\authn.pl $ARGV[$i + 1]");
		system("move authn_plot_fail.png $theTimeFolder\\pdweb_authn");
		system("move authn_plot_pass.png $theTimeFolder\\pdweb_authn");
		system("move authn_plot_pwd_exp.png $theTimeFolder\\pdweb_authn");
		system("move authn_plot_max_time.png $theTimeFolder\\pdweb_authn");
		system("move authn_plot_avg_time.png $theTimeFolder\\pdweb_authn");
		system("move authn_plot_total_time.png $theTimeFolder\\pdweb_authn");
		$i++;
	}
	elsif( ($ARGV[$i] eq "-az") || ($ARGV[$i] eq "-authz") )			#authz case
	{
		print "Plotting pdweb.authz...\n";
		system("mkdir $theTimeFolder\\pdweb_authz");
		system("perl plot_files\\pdweb.authz\\authz.pl $ARGV[$i + 1]");
		system("move authz_plot_fail.png $theTimeFolder\\pdweb_authz");
		system("move authz_plot_pass.png $theTimeFolder\\pdweb_authz");
		$i++;
	}
	elsif( ($ARGV[$i] eq "-c")  || ($ARGV[$i] eq "-certcallbackcache") )		#certcallbackcache case
	{
		print "Plotting pdweb.certcallbackcache...\n";
		system("mkdir $theTimeFolder\\pdweb_certcallbackcache");
		system("perl plot_files\\pdweb.certcallbackcache\\certcallbackcache.pl $ARGV[$i + 1]");
		system("move certcallbackcache_plot_miss.png $theTimeFolder\\pdweb_certcallbackcache");
		system("move certcallbackcache_plot_hit.png $theTimeFolder\\pdweb_certcallbackcache");
		system("move certcallbackcache_plot_add.png $theTimeFolder\\pdweb_certcallbackcache");
		system("move certcallbackcache_plot_del.png $theTimeFolder\\pdweb_certcallbackcache");
		system("move certcallbackcache_plot_inactive.png $theTimeFolder\\pdweb_certcallbackcache");
		system("move certcallbackcache_plot_lifetime.png $theTimeFolder\\pdweb_certcallbackcache");
		system("move certcallbackcache_plot_LRU_expired.png $theTimeFolder\\pdweb_certcallbackcache");
		$i++;
	}
	elsif( ($ARGV[$i] eq "-d")  || ($ARGV[$i] eq "-doccache") )			#doccache case
	{
		print "Plotting pdweb.doccache...\n";
		system("mkdir $theTimeFolder\\pdweb_doccache");
		system("perl plot_files\\pdweb.doccache\\doccache.pl $ARGV[$i + 1]");
		system("move doccache_plot_general_errors.png $theTimeFolder\\pdweb_doccache");
		system("move doccache_plot_uncachable.png $theTimeFolder\\pdweb_doccache");
		system("move doccache_plot_pending_deletes.png $theTimeFolder\\pdweb_doccache");
		system("move doccache_plot_pending_size.png $theTimeFolder\\pdweb_doccache");
		system("move doccache_plot_misses.png $theTimeFolder\\pdweb_doccache");
		system("move doccache_plot_size.png $theTimeFolder\\pdweb_doccache");
		system("move doccache_plot_count.png $theTimeFolder\\pdweb_doccache");
		system("move doccache_plot_hits.png $theTimeFolder\\pdweb_doccache");
		system("move doccache_plot_stale_hits.png $theTimeFolder\\pdweb_doccache");
		system("move doccache_plot_create_waits.png $theTimeFolder\\pdweb_doccache");
		system("move doccache_plot_cache_no_room.png $theTimeFolder\\pdweb_doccache");
		system("move doccache_plot_additions.png $theTimeFolder\\pdweb_doccache");
		system("move doccache_plot_aborts.png $theTimeFolder\\pdweb_doccache");
		system("move doccache_plot_deletes.png $theTimeFolder\\pdweb_doccache");
		system("move doccache_plot_updates.png $theTimeFolder\\pdweb_doccache");
		system("move doccache_plot_too_big_errors.png $theTimeFolder\\pdweb_doccache");
		system("move doccache_plot_MT_errors.png $theTimeFolder\\pdweb_doccache");
		$i++;
	}
	elsif( ($ARGV[$i] eq "-dr")  || ($ARGV[$i] eq "-drains") )			#drains case
	{
		print "Plotting pdweb.drains...\n";
		system("mkdir $theTimeFolder\\pdweb_drains");
		system("perl plot_files\\pdweb.drains\\drains.pl $ARGV[$i + 1]");
		system("move drains_plot_failed_closes.png $theTimeFolder\\pdweb_drains");
		system("move drains_plot_max_draining_FDs.png $theTimeFolder\\pdweb_drains");
		system("move drains_plot_failed_selects.png $theTimeFolder\\pdweb_drains");
		system("move drains_plot_FDs_closed_HIWAT.png $theTimeFolder\\pdweb_drains");
		system("move drains_plot_FDs_closed_FLOOD.png $theTimeFolder\\pdweb_drains");
		system("move drains_plot_timed_out_FDs.png $theTimeFolder\\pdweb_drains");
		system("move drains_plot_idle_awakenings.png $theTimeFolder\\pdweb_drains");
		system("move drains_plot_bytes_drained.png $theTimeFolder\\pdweb_drains");
		system("move drains_plot_drained_FDs.png $theTimeFolder\\pdweb_drains");
		system("move drains_plot_average_bytes_drained.png $theTimeFolder\\pdweb_drains");
		$i++;
	}
	elsif( ($ARGV[$i] eq "-h")  || ($ARGV[$i] eq "-http") )				#http case
	{
		print "Plotting pdweb.http...\n";
		system("mkdir $theTimeFolder\\pdweb_http");
		system("perl plot_files\\pdweb.http\\http.pl $ARGV[$i + 1]");
		system("move http_plot_reqs.png $theTimeFolder\\pdweb_http");
		system("move http_plot_max_worker_time.png $theTimeFolder\\pdweb_http");
		system("move http_plot_max_webseal_time.png $theTimeFolder\\pdweb_http");
		system("move http_plot_total_worker_time.png $theTimeFolder\\pdweb_http");
		system("move http_plot_total_webseal_time.png $theTimeFolder\\pdweb_http");
		system("move http_plot_average_worker_time.png $theTimeFolder\\pdweb_http");
		system("move http_plot_average_webseal_time.png $theTimeFolder\\pdweb_http");
		$i++;
	}
	elsif( ($ARGV[$i] eq "-hs")  || ($ARGV[$i] eq "-https") )			#https case
	{
		print "Plotting pdweb.https...\n";
		system("mkdir $theTimeFolder\\pdweb_https");
		system("perl plot_files\\pdweb.https\\https.pl $ARGV[$i + 1]");
		system("move https_plot_reqs.png $theTimeFolder\\pdweb_https");
		system("move https_plot_max_worker_time.png $theTimeFolder\\pdweb_https");
		system("move https_plot_max_webseal_time.png $theTimeFolder\\pdweb_https");
		system("move https_plot_total_worker_time.png $theTimeFolder\\pdweb_https");
		system("move https_plot_total_webseal_time.png $theTimeFolder\\pdweb_https");
		system("move https_plot_average_worker_time.png $theTimeFolder\\pdweb_https");
		system("move https_plot_average_webseal_time.png $theTimeFolder\\pdweb_https");
		$i++;
	}
	elsif( ($ARGV[$i] eq "-j")  || ($ARGV[$i] eq "-jct") )				#jct case
	{
		print "Plotting pdweb.jct...\n";
		system("mkdir $theTimeFolder\\pdweb_jct");
		while($ARGV[$i + 1] =~ /^[^-]/)
		{
			system("perl plot_files\\pdweb.jct.#\\jct_single.pl $theTimeFolder $ARGV[$i + 1]");
			$i++;
		}
	}
	elsif( ($ARGV[$i] eq "-dj")  || ($ARGV[$i] eq "-djct") )				#jct case
	{
		print "Plotting pdweb.jct...\n";
		system("mkdir $theTimeFolder\\pdweb_jct");
		system("perl plot_files\\pdweb.jct.#\\jct_directory.pl $theTimeFolder $ARGV[$i + 1]");
		$i++;
	}
	elsif($ARGV[$i] eq "-jmt")							#jmt case
	{
		print "Plotting pdweb.jmt...\n";
		system("mkdir $theTimeFolder\\pdweb_jmt");
		system("perl plot_files\\pdweb.jmt\\jmt.pl $ARGV[$i + 1]");
		system("move jmt_plot.png $theTimeFolder\\pdweb_jmt");
		$i++;
	}
	elsif( ($ARGV[$i] eq "-s")  || ($ARGV[$i] eq "-sescache") )			#sescache case
	{
		print "Plotting pdweb.sescache...\n";
		system("mkdir $theTimeFolder\\pdweb_sescache");
		system("perl plot_files\\pdweb.sescache\\sescache.pl $ARGV[$i + 1]");
		system("move sescache_plot_miss.png $theTimeFolder\\pdweb_sescache");
		system("move sescache_plot_hit.png $theTimeFolder\\pdweb_sescache");
		system("move sescache_plot_add.png $theTimeFolder\\pdweb_sescache");
		system("move sescache_plot_del.png $theTimeFolder\\pdweb_sescache");
		system("move sescache_plot_inactive.png $theTimeFolder\\pdweb_sescache");
		system("move sescache_plot_lifetime.png $theTimeFolder\\pdweb_sescache");
		system("move sescache_plot_LRU_expired.png $theTimeFolder\\pdweb_sescache");
		$i++;
	}
	elsif( ($ARGV[$i] eq "-t")  || ($ARGV[$i] eq "-threads") )			#threads case
	{
		print "Plotting pdweb.threads...\n";
		system("mkdir $theTimeFolder\\pdweb_threads");
		system("perl plot_files\\pdweb.threads\\threads.pl $ARGV[$i + 1]");
		system("move threads_plot.png $theTimeFolder\\pdweb_threads");
		system("move threads_plot_default.png $theTimeFolder\\pdweb_threads");
		$i++;
	}
	elsif( ($ARGV[$i] eq "-u")  || ($ARGV[$i] eq "-usersessidcache") )		#usersessidcache case
	{
		print "Plotting pdweb.usersessidcache...\n";
		system("mkdir $theTimeFolder\\pdweb_usersessidcache");
		system("perl plot_files\\pdweb.usersessidcache\\usersessidcache.pl $ARGV[$i + 1]");
		system("move usersessidcache_plot_miss.png $theTimeFolder\\pdweb_usersessidcache");
		system("move usersessidcache_plot_hit.png $theTimeFolder\\pdweb_usersessidcache");
		system("move usersessidcache_plot_add.png $theTimeFolder\\pdweb_usersessidcache");
		system("move usersessidcache_plot_del.png $theTimeFolder\\pdweb_usersessidcache");
		system("move usersessidcache_plot_inactive.png $theTimeFolder\\pdweb_usersessidcache");
		system("move usersessidcache_plot_lifetime.png $theTimeFolder\\pdweb_usersessidcache");
		system("move usersessidcache_plot_LRU_expired.png $theTimeFolder\\pdweb_usersessidcache");
		$i++;
	}
	elsif( ($ARGV[$i] eq "-v")  || ($ARGV[$i] eq "-vhj") )				#vhj case
	{
		print "Plotting pdweb.vhj...\n";
		system("mkdir $theTimeFolder\\pdweb_vhj");
		while($ARGV[$i + 1] =~ /^[^-]/)
		{
			system("perl plot_files\\pdweb.vhj.#\\vhj_single.pl $theTimeFolder $ARGV[$i + 1]");
			$i++;
		}
	}
	elsif( ($ARGV[$i] eq "-dv")  || ($ARGV[$i] eq "-dvhj") )				#jct case
	{
		print "Plotting pdweb.vhj...\n";
		system("mkdir $theTimeFolder\\pdweb_vhj");
		system("perl plot_files\\pdweb.vhj.#\\vhj_directory.pl $theTimeFolder $ARGV[$i + 1]");
		$i++;
	}
	elsif( ($ARGV[$i] eq "-help") || ($ARGV[$i] eq "--h") )	#print usage information
	{
		system("rmdir $theTimeFolder");
		print "\n\nUSAGE\:\n";
		print "\nperl graph_generator.pl [-help | --h] [-out | -o] [-stat_flag_1 log_file(s)] ...\n";
		print "\nFLAGS:\n";
		print "\n\-help or \-\-h\n";
		print "These flags will display this usage message.\n";
		print "\n\-out or \-o output_file\n";
		print "These flags will allow you to specify the name of the output folder\n";
		print "which will contain all of the gnuplot graphs. The string entered will\n";
		print "always be followed by a timestamp to avoid duplicates.\n";
		print "\n\-an or \-authn authn_log_file\n";
		print "These flags will plot authn performance data specified in authn_log_file\n";
		print "\n\-az or \-authz authz_log_file\n";
		print "These flags will plot authz performance data specified in authz_log_file\n";
		print "\n\-c or \-certcallbackcache certcallbackcache_log_file\n";
		print "These flags will plot certcallbackcache performance data specified in certcallbackcache_log_file\n";
		print "\n\-d or \-doccache doccache_log_file\n";
		print "These flags will plot doccache performance data specified in doccache_log_file\n";
		print "\n\-dr or \-drains drains_log_file\n";
		print "These flags will plot drains performance data specified in drains_log_file\n";
		print "\n\-h or \-http http_log_file\n";
		print "These flags will plot http performance data specified in http_log_file\n";
		print "\n\-hs or \-https https_log_file\n";
		print "These flags will plot https performance data specified in https_log_file\n";
		print "\n\-j or \-jct jct_log_file_1 [jct_log_file_2] ...\n";
		print "These flags will plot jct performance data specified in each jct_log_file after the flag until the next flag\n";
		print "\n\-dj or \-djct jct_log_directory\n";
		print "These flags will plot jct performance data for each file in jct_log_directory.\n";
		print "jct_log_directory can contain any log files, but warning messages\n";
		print "will appear for every non-jct log file in jct_log_directory.\n";
		print "File names can be arbitrary.\n";
		print "\n\-jmt jmt_log_file\n";
		print "This flags will plot jmt performance data specified in jmt_log_file\n";
		print "\n\-s or \-sescache sescache_log_file\n";
		print "These flags will plot sescache performance data specified in sescache_log_file\n";
		print "\n\-t or \-threads threads_log_file\n";
		print "These flags will plot threads performance data specified in threads_log_file\n";
		print "\n\-u or \-usersessidcache usersessidcache_log_file\n";
		print "These flags will plot usersessidcache performance data specified in usersessidcache_log_file\n";
		print "\n\-v or \-vhj vhj_log_file_1 [vhj_log_file_2] ...\n";
		print "These flags will plot vhj performance data specified in each vhj_log_file after the flag until the next flag\n";
		print "\n\-dv or \-dvhj authn_log_directory\n";
		print "These flags will plot vhj performance data for each file in vhj_log_directory.\n";
		print "jct_log_directory can contain any log files, but warning messages\n";
		print "will appear for every non-jct log file in jct_log_directory.\n";
		print "File names can be arbitrary.\n";
		print "\nGENERAL INFO:\n";
		print "\nThis perl script will create gnuplot graphs from pdweb performance logs\n";
		print "so that patterns and spikes in activity can easily be spotted and solutions\n";
		print "to customer problems can be expedited.\n";
		print "\nEach graph plots a single pdweb statistic over the time it was gathered.\n";
		print "All of the graphs for a single stat are put in a directory, and all of these\n";
		print "directories are put into the output folder which is specified by the user\n";
		print "with the -out or -o flags or the default name which is a timestamp. The script\n";
		print "can plot anywhere from a single statistic to all of the statistics at once,\n";
		print "depending on the input.\n";
		print "\nCreated by Denis Sokolov, IBM 2010.\nProject Manager: Nick Lloyd.";
	}
	elsif($ARGV[$i] eq "-out" || $ARGV[$i] eq "-o")
	{
		$i++;	#skip -out because it was already taken care of
	}
	$i++;
}