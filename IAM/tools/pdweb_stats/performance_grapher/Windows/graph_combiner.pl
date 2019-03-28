#!/usr/local/bin/perl
#Author. Denis K. Sokolov 11/2010 IBM
#
#This is a driver for performance data graphing perl scripts
#usage: perl graph_combiner.pl stat1 -l log1 [-c color1] [-a axis_label1] stat2 -l log2 [-c color2] [-a axis_label2] -o out_plot -t title
#
#I/O:
#Input: specific performance statistic descriptors and their corresponding log files
#Output: combined gnuplot graph
#
#vars:
#stat1 is the name of the first statistic (required user input)
#stat2 is the name of the second statistic (required user input)
#outplot is the name of the output file (optional user input)
#interval is the preferred interval of the y2 axis (only applies to stat2, calculated in the script)
#using holds the column numbers for the desired data so that gnuplot will plot the correct stat (calculated by the script)
#color1 is the color of the first stat (optional user input)
#color2 is the color of the second stat (optional user input)
#i is a loop counter
#title is the title of the graph (optional user input)
#log1 is the log file for the first stat (required user input)
#log2 is the log file for the second stat (required user input)
#label1 is the axis label for the first stat (optional user input)
#label2 is the axis label for the second stat (optional user input)

$interval = "10";	#default value

$color1 = "";
$color2 = "";
$stat1 = "";
$stat2 = "";
$log1 = "";
$log2 = "";
$out_plot = "";
$title = "";
$label1 = "";
$label2 = "";
$i = 0;
while($i < $#ARGV + 1)
{
	if($ARGV[$i] eq "-h" || $ARGV[$i] eq "--h" || $ARGV[$i] eq "-help")
	{
		print "USAGE:";
		print "\nperl graph_combiner.pl stat1 -l log1 [-c color1] [-a axis_label1] stat2 -l log2 [-c color2] [-a axis_label2] [-o out_plot] [-t title]\n";
		print "Items in square brackets represent optional inputs.";
		print "\n\n<stat1> and <stat2> can take any of the values from the following list or their shorthand (in parentheses):";
		print "\nauthn-pass (an-p)\nauthn-fail (an-f)\nauthn-pwd-exp (an-p-e)\nauthn-max (an-m)\nauthn-total (an-t)\nauthn-avg (an-a)\n";
		print "authz-pass (az-p)\nauthz-fail (az-f)\ncertcallbackcache-hit (c-h)\ncertcallbackcache-miss (c-m)\n";
		print "certcallbackcache-add (c-a)\ncertcallbackcache-del (c-d)\ncertcallbackcache-inactive (c-i)\ncertcallbackcache-lifetime (c-l)\n";
		print "certcallbackcache-lru-exp (c-l-e)\ndoccache-general-errors (d-g-e)\ndoccache-uncachable (d-u)\ndoccache-pending-deletes (d-p-d)\n";
		print "doccache-pending-size (d-p-s)\ndoccache-misses (d-m)\ndoccache-max-size (d-m-s)\n";
		print "doccache-max-entry-size (d-m-e-s)\ndoccache-default-max-age (d-d-m-a)\ndoccache-size (d-s)\ndoccache-count (d-c)\ndoccache-hits (d-h)\n";
		print "doccache-stale-hits (d-s-h)\ndoccache-create-waits (d-c-w)\ndoccache-cache-no-room (d-c-n-r)\ndoccache-additions (d-add)\n";
		print "doccache-aborts (d-ab)\ndoccache-deletes (d-d)\ndoccache-updates (d-u)\ndoccache-too-big-errors (d-t-b-e)\ndoccache-mt-errors (d-m-e)\n";
		print "drains-draining-fds (dr-d-ing-f)\ndrains-failed-closes (dr-f-c)\ndrains-failed-selects (dr-f-s)\ndrains-fds-closed-hiwat (dr-f-c-h)\n";
		print "drains-fds-closed-flood (dr-f-c-f)\ndrains-timed-out-fds (dr-t-o-f)\ndrains-idle-awakenings (dr-i-a)\ndrains-bytes-drained (dr-b-d)\n";
		print "drains-drained-fds (dr-d-ed-f)\ndrains-avg-bytes-drained (dr-a-b-d)\nhttp-reqs (h-r)\nhttp-max-worker (h-m-w)\nhttp-avg-worker (h-a-w)\n";
		print "http-total-worker (h-t-w)\nhttp-max-webseal (h-m-web)\nhttp-avg-webseal (h-a-web)\nhttp-total-webseal (h-t-web)\nhttps-reqs (hs-r)\n";
		print "https-max-worker (hs-m-w)\nhttps-avg-worker (hs-a-w)\nhttps-total-worker (hs-t-w)\nhttps-max-webseal (hs-m-web)\nhttps-avg-webseal (hs-a-web)\n";
		print "https-total-webseal (hs-t-web)\njct-reqs (j-r)\njct-max (j-m)\njct-avg (j-a)\njct-total (j-t)\njmt-hits (j-h)\nsescache-hit (s-h)\n";
		print "sescache-miss (s-m)\nsescache-add (s-a)\nsescache-del (s-d)\nsescache-inactive (s-i)\nsescache-lifetime (s-l)\nsescahe-lru-exp (s-l-e)\n";
		print "threads-active (t-a)\nthreads-total (t-t)\nthreads-default-active (t-d-a)\nthreads-default-total (t-d-t)\nusersessidcache-hit (u-h)\n";
		print "usersessidcache-miss (u-m)\nusersessidcache-add (u-a)\nusersessidcache-del (u-d)\nusersessidcache-inactive (u-i)\nusersessidcache-lifetime (u-l)\n";
		print "usersessidcache-lru-exp (u-l-e)\nvhj-reqs (v-r)\nvhj-max (v-m)\nvhj-avg (v-a)\nvhj-total (v-t)\n";
		print "\nThe log file specified after the -l flag must correspond to the stat that it follows. The log file input is required.\n";
		print "\nThe colors (invoked with the -c flag) supported in gnuplot are as follows (specifying color is optional):\n";
		print "white\nblack\ndark-grey\nred\nweb-green\nweb-blue\ndark-magenta\ndark-cyan\ndark-orange\n";
		print "dark-yellow\nroyalblue\ngoldenrod\ndark-spring-green\npurple\nsteelblue\ndark-red\ndark-chartreuse\norchid\n";
		print "aquamarine\nbrown\nyellow\nturquoise\ngrey0\ngrey10\ngrey20\ngrey30\ngrey40\ngrey50\ngrey60\ngrey70\ngrey\ngrey80\ngrey90\n";
		print "grey100\nlight-red\nlight-green\nlight-blue\nlight-magenta\nlight-cyan\nlight-goldenrod\nlight-pink\nlight-turquoise\ngold\ngreen\ndark-green\n";
		print "spring-green\nforest-green\nsea-green\nblue\ndark-blue\nmidnight-blue\nnavy\nmedium-blue\nskyblue\n";
		print "cyan\nmagenta\ndark-turquoise\ndark-pink\ncoral\nlight-coral\norange-red\nsalmon\ndark-salmon\nkhaki\ndark-khaki\ndark-goldenrod\n";
		print "beige\nolive\norange\nviolet\ndark-violet\ndark-plum\ndark-olivegreen\norangered4\nbrown4\nsienna4\norchid4\nmediumpurple3\n";
		print "slateblue1\nyellow4\nsienna1\ntan1\nsandybrown\nlight-salmon\npink\nkhaki1\nlemonchiffon\nbisque\nhoneydew\nslategrey\n";
		print "seagreen\nantiquewhite\nchartreuse\ngreenyellow\ngray\nlight-gray\nlight-grey\ndark-gray\nslategray\ngray0\ngray10\ngray20\n";
		print "gray30\ngray40\ngray50\ngray60\ngray70\ngray80\ngray90\ngray100\n";
		print "\nThis script can only be used to combine two graphs of single pdweb stats.\n";
		print "Output file is a .png file. When specifying the output file name with the -o option, omit the .png extention and just type the file name.\n";
		print "Log file and stat inputs are required, but output file name, color1, color2, title, axis_label1, and axis_label2 are optional.\n\n";
		exit 0;
	}
	if(($ARGV[$i] eq "-c") || ($ARGV[$i] eq "-color"))	#user input color
	{
		if($color1 eq "")
		{
			$color1 = $ARGV[$i + 1];	#assign color1
			$i = $i + 2;			#increment i to next relevant input
		}
		else
		{
			$color2 = $ARGV[$i + 1];	#assign color2
			$i = $i + 2;			#increment i to next relevant input
		}
	}
	elsif(($ARGV[$i] eq "-l") || ($ARGV[$i] eq "-log"))	#user log file specification
	{
		if($log1 eq "")
		{
			$log1 = $ARGV[$i + 1];		#assign log1
			$i = $i + 2;
		}
		else
		{
			$log2 = $ARGV[$i + 1];		#assign log2
			$i = $i + 2;
		}
	}
	elsif(($ARGV[$i] eq "-a") || ($ARGV[$i] eq "-axis"))	#user axis label specification
	{
		if($label1 eq "")
		{
			$label1 = $ARGV[$i + 1];		#assign label1
			$i = $i + 2;
		}
		else
		{
			$label2 = $ARGV[$i + 1];		#assign label2
			$i = $i + 2;
		}
	}
	elsif(($ARGV[$i] eq "-out") || ($ARGV[$i] eq "-o"))	#user input for output file
	{
		$out_plot = $ARGV[$i + 1];		#assign output file name
		$i = $i + 2;				#increment i to next relevant input
	}
	elsif($ARGV[$i] eq "-t")			#user input for graph title
	{
		$title = $ARGV[$i + 1];			#assign output file name
		$i = $i + 2;				#increment i to next relevant input
	}
	else						#statistic input
	{
		if($stat1 eq "")
		{
			$stat1 = $ARGV[$i++];
		}
		else
		{
			$stat2 = $ARGV[$i++];
		}
	}
}

print "plotting...\n";

if($out_plot eq "")		#if output file was not specified by the user
{
	#calculate current time
	@months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
	@weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
	($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
	$year = 1900 + $yearOffset;

	$out_plot = $stat1."_".$stat2."\_$weekDays[$dayOfWeek]_$months[$month]\-$dayOfMonth\-$year\_$hour\H$minute\M$second\S_graphs";	#construct file name
}
if($color1 eq "")
{
	$color1 = "blue";
}
if($color2 eq "")
{
	$color2 = "red";
}
if($label1 eq "")
{
	$label1 = $stat1;
}
if($label2 eq "")
{
	$label2 = $stat2;
}
if($title eq "")
{
	$title = "Performance of: $stat1 and $stat2";
}

if($stat1 eq "authn-pass" || $stat1 eq "an-p") {system("perl plot_files/pdweb.authn/combinable_authn.pl $log1 g1 -1"); $using1 = "1:2";}
elsif($stat1 eq "authn-fail" || $stat1 eq "an-f") {system("perl plot_files/pdweb.authn/combinable_authn.pl $log1 g1 -1"); $using1 = "1:3";}
elsif($stat1 eq "authn-pwd-exp" || $stat1 eq "an-p-e") {system("perl plot_files/pdweb.authn/combinable_authn.pl $log1 g1 -1"); $using1 = "1:4";}
elsif($stat1 eq "authn-max" || $stat1 eq "an-m") {system("perl plot_files/pdweb.authn/combinable_authn.pl $log1 g1 -1"); $using1 = "1:5";}
elsif($stat1 eq "authn-total" || $stat1 eq "an-t") {system("perl plot_files/pdweb.authn/combinable_authn.pl $log1 g1 -1"); $using1 = "1:7";}
elsif($stat1 eq "authn-avg" || $stat1 eq "an-a") {system("perl plot_files/pdweb.authn/combinable_authn.pl $log1 g1 -1"); $using1 = "1:6";}
elsif($stat1 eq "authz-pass" || $stat1 eq "az-p") {system("perl plot_files/pdweb.authz/combinable_authz.pl $log1 g1 -1"); $using1 = "1:2";}
elsif($stat1 eq "authz-fail" || $stat1 eq "az-f") {system("perl plot_files/pdweb.authz/combinable_authz.pl $log1 g1 -1"); $using1 = "1:3";}
elsif($stat1 eq "certcallbackcache-hit" || $stat1 eq "c-h") {system("perl plot_files/pdweb.certcallbackcache/combinable_certcallbackcache.pl $log1 g1 -1"); $using1 = "1:2";}
elsif($stat1 eq "certcallbackcache-miss" || $stat1 eq "c-m") {system("perl plot_files/pdweb.certcallbackcache/combinable_certcallbackcache.pl $log1 g1 -1"); $using1 = "1:3";}
elsif($stat1 eq "certcallbackcache-add" || $stat1 eq "c-a") {system("perl plot_files/pdweb.certcallbackcache/combinable_certcallbackcache.pl $log1 g1 -1"); $using1 = "1:4";}
elsif($stat1 eq "certcallbackcache-del" || $stat1 eq "c-d") {system("perl plot_files/pdweb.certcallbackcache/combinable_certcallbackcache.pl $log1 g1 -1"); $using1 = "1:5";}
elsif($stat1 eq "certcallbackcache-inactive" || $stat1 eq "c-i") {system("perl plot_files/pdweb.certcallbackcache/combinable_certcallbackcache.pl $log1 g1 -1"); $using1 = "1:6";}
elsif($stat1 eq "certcallbackcache-lifetime" || $stat1 eq "c-l") {system("perl plot_files/pdweb.certcallbackcache/combinable_certcallbackcache.pl $log1 g1 -1"); $using1 = "1:7";}
elsif($stat1 eq "certcallbackcache-lru-exp" || $stat1 eq "c-l-e") {system("perl plot_files/pdweb.certcallbackcache/combinable_certcallbackcache.pl $log1 g1 -1"); $using1 = "1:8";}
elsif($stat1 eq "doccache-general-errors" || $stat1 eq "d-g-e") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g1 -1"); $using1 = "1:2";}
elsif($stat1 eq "doccache-uncachable" || $stat1 eq "d-u") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g1 -1"); $using1 = "1:3";}
elsif($stat1 eq "doccache-pending-deletes" || $stat1 eq "d-p-d") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g1 -1"); $using1 = "1:4";}
elsif($stat1 eq "doccache-pending-size" || $stat1 eq "d-p-s") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g1 -1"); $using1 = "1:5";}
elsif($stat1 eq "doccache-misses" || $stat1 eq "d-m") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g1 -1"); $using1 = "1:6";}
elsif($stat1 eq "doccache-max-size" || $stat1 eq "d-m-s") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g1 -1"); $using1 = "1:8";}
elsif($stat1 eq "doccache-max-entry-size" || $stat1 eq "d-m-e-s") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g1 -1"); $using1 = "1:9";}
elsif($stat1 eq "doccache-default-max-age" || $stat1 eq "d-d-m-a") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g1 -1"); $using1 = "1:10";}
elsif($stat1 eq "doccache-size" || $stat1 eq "d-s") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g1 -1"); $using1 = "1:11";}
elsif($stat1 eq "doccache-count" || $stat1 eq "d-c") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g1 -1"); $using1 = "1:12";}
elsif($stat1 eq "doccache-hits" || $stat1 eq "d-h") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g1 -1"); $using1 = "1:13";}
elsif($stat1 eq "doccache-stale-hits" || $stat1 eq "d-s-h") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g1 -1"); $using1 = "1:14";}
elsif($stat1 eq "doccache-create-waits" || $stat1 eq "d-c-w") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g1 -1"); $using1 = "1:15";}
elsif($stat1 eq "doccache-cache-no-room" || $stat1 eq "d-c-n-r") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g1 -1"); $using1 = "1:16";}
elsif($stat1 eq "doccache-additions" || $stat1 eq "d-add") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g1 -1"); $using1 = "1:17";}
elsif($stat1 eq "doccache-aborts" || $stat1 eq "d-ab") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g1 -1"); $using1 = "1:18";}
elsif($stat1 eq "doccache-deletes" || $stat1 eq "d-d") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g1 -1"); $using1 = "1:19";}
elsif($stat1 eq "doccache-updates" || $stat1 eq "d-u") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g1 -1"); $using1 = "1:20";}
elsif($stat1 eq "doccache-too-big-errors" || $stat1 eq "d-t-b-e") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g1 -1"); $using1 = "1:21";}
elsif($stat1 eq "doccache-mt-errors" || $stat1 eq "d-m-e") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g1 -1"); $using1 = "1:22";}
elsif($stat1 eq "drains-draining-fds" || $stat1 eq "dr-d-ing-f") {system("perl plot_files/pdweb.drains/combinable_drains.pl $log1 g1 -1"); $using1 = "1:2";}
elsif($stat1 eq "drains-failed-closes" || $stat1 eq "dr-f-c") {system("perl plot_files/pdweb.drains/combinable_drains.pl $log1 g1 -1"); $using1 = "1:3";}
elsif($stat1 eq "drains-failed-selects" || $stat1 eq "dr-f-s") {system("perl plot_files/pdweb.drains/combinable_drains.pl $log1 g1 -1"); $using1 = "1:4";}
elsif($stat1 eq "drains-fds-closed-hiwat" || $stat1 eq "dr-f-c-h") {system("perl plot_files/pdweb.drains/combinable_drains.pl $log1 g1 -1"); $using1 = "1:5";}
elsif($stat1 eq "drains-fds-closed-flood" || $stat1 eq "dr-f-c-f") {system("perl plot_files/pdweb.drains/combinable_drains.pl $log1 g1 -1"); $using1 = "1:6";}
elsif($stat1 eq "drains-timed-out-fds" || $stat1 eq "dr-t-o-f") {system("perl plot_files/pdweb.drains/combinable_drains.pl $log1 g1 -1"); $using1 = "1:7";}
elsif($stat1 eq "drains-idle-awakenings" || $stat1 eq "dr-i-a") {system("perl plot_files/pdweb.drains/combinable_drains.pl $log1 g1 -1"); $using1 = "1:8";}
elsif($stat1 eq "drains-bytes-drained" || $stat1 eq "dr-b-d") {system("perl plot_files/pdweb.drains/combinable_drains.pl $log1 g1 -1"); $using1 = "1:9";}
elsif($stat1 eq "drains-drained-fds" || $stat1 eq "dr-d-ed-f") {system("perl plot_files/pdweb.drains/combinable_drains.pl $log1 g1 -1"); $using1 = "1:10";}
elsif($stat1 eq "drains-avg-bytes-drained" || $stat1 eq "dr-a-b-d") {system("perl plot_files/pdweb.drains/combinable_drains.pl $log1 g1 -1"); $using1 = "1:11";}
elsif($stat1 eq "http-reqs" || $stat1 eq "h-r") {system("perl plot_files/pdweb.http/combinable_http.pl $log1 g1 -1"); $using1 = "1:2";}
elsif($stat1 eq "http-max-worker" || $stat1 eq "h-m-w") {system("perl plot_files/pdweb.http/combinable_http.pl $log1 g1 -1"); $using1 = "1:3";}
elsif($stat1 eq "http-avg-worker" || $stat1 eq "h-a-w") {system("perl plot_files/pdweb.http/combinable_http.pl $log1 g1 -1"); $using1 = "1:4";}
elsif($stat1 eq "http-total-worker" || $stat1 eq "h-t-w") {system("perl plot_files/pdweb.http/combinable_http.pl $log1 g1 -1"); $using1 = "1:5";}
elsif($stat1 eq "http-max-webseal" || $stat1 eq "h-m-web") {system("perl plot_files/pdweb.http/combinable_http.pl $log1 g1 -1"); $using1 = "1:6";}
elsif($stat1 eq "http-avg-webseal" || $stat1 eq "h-a-web") {system("perl plot_files/pdweb.http/combinable_http.pl $log1 g1 -1"); $using1 = "1:7";}
elsif($stat1 eq "http-total-webseal" || $stat1 eq "h-t-web") {system("perl plot_files/pdweb.http/combinable_http.pl $log1 g1 -1"); $using1 = "1:8";}
elsif($stat1 eq "https-reqs" || $stat1 eq "hs-r") {system("perl plot_files/pdweb.https/combinable_https.pl $log1 g1 -1"); $using1 = "1:2";}
elsif($stat1 eq "https-max-worker" || $stat1 eq "hs-m-w") {system("perl plot_files/pdweb.https/combinable_https.pl $log1 g1 -1"); $using1 = "1:3";}
elsif($stat1 eq "https-avg-worker" || $stat1 eq "hs-a-w") {system("perl plot_files/pdweb.https/combinable_https.pl $log1 g1 -1"); $using1 = "1:4";}
elsif($stat1 eq "https-total-worker" || $stat1 eq "hs-t-w") {system("perl plot_files/pdweb.https/combinable_https.pl $log1 g1 -1"); $using1 = "1:5";}
elsif($stat1 eq "https-max-webseal" || $stat1 eq "hs-m-web") {system("perl plot_files/pdweb.https/combinable_https.pl $log1 g1 -1"); $using1 = "1:6";}
elsif($stat1 eq "https-avg-webseal" || $stat1 eq "h-a-web") {system("perl plot_files/pdweb.https/combinable_https.pl $log1 g1 -1"); $using1 = "1:7";}
elsif($stat1 eq "https-total-webseal" || $stat1 eq "hs-t-web") {system("perl plot_files/pdweb.https/combinable_https.pl $log1 g1 -1"); $using1 = "1:8";}
elsif($stat1 eq "jct-reqs" || $stat1 eq "j-r") {system("perl plot_files/pdweb.jct.#/combinable_jct.pl $log1 g1 -1"); $using1 = "1:2";}
elsif($stat1 eq "jct-max" || $stat1 eq "j-m") {system("perl plot_files/pdweb.jct.#/combinable_jct.pl $log1 g1 -1"); $using1 = "1:3";}
elsif($stat1 eq "jct-avg" || $stat1 eq "j-a") {system("perl plot_files/pdweb.jct.#/combinable_jct.pl $log1 g1 -1"); $using1 = "1:4";}
elsif($stat1 eq "jct-total" || $stat1 eq "j-t") {system("perl plot_files/pdweb.jct.#/combinable_jct.pl $log1 g1 -1"); $using1 = "1:5";}
elsif($stat1 eq "jmt-hits" || $stat1 eq "j-h") {system("perl plot_files/pdweb.jmt/combinable_jmt.pl $log1 g1 -1"); $using1 = "1:2";}
elsif($stat1 eq "sescache-hit" || $stat1 eq "s-h") {system("perl plot_files/pdweb.sescache/combinable_sescache.pl $log1 g1 -1"); $using1 = "1:2";}
elsif($stat1 eq "sescache-miss" || $stat1 eq "s-m") {system("perl plot_files/pdweb.sescache/combinable_sescache.pl $log1 g1 -1"); $using1 = "1:3";}
elsif($stat1 eq "sescache-add" || $stat1 eq "s-a") {system("perl plot_files/pdweb.sescache/combinable_sescache.pl $log1 g1 -1"); $using1 = "1:4";}
elsif($stat1 eq "sescache-del" || $stat1 eq "s-d") {system("perl plot_files/pdweb.sescache/combinable_sescache.pl $log1 g1 -1"); $using1 = "1:5";}
elsif($stat1 eq "sescache-inactive" || $stat1 eq "s-i") {system("perl plot_files/pdweb.sescache/combinable_sescache.pl $log1 g1 -1"); $using1 = "1:6";}
elsif($stat1 eq "sescache-lifetime" || $stat1 eq "s-l") {system("perl plot_files/pdweb.sescache/combinable_sescache.pl $log1 g1 -1"); $using1 = "1:7";}
elsif($stat1 eq "sescache-lru-exp" || $stat1 eq "s-l-e") {system("perl plot_files/pdweb.sescache/combinable_sescache.pl $log1 g1 -1"); $using1 = "1:8";}
elsif($stat1 eq "threads-active" || $stat1 eq "t-a") {system("perl plot_files/pdweb.threads/combinable_threads.pl $log1 g1 -1"); $using1 = "1:2";}
elsif($stat1 eq "threads-total" || $stat1 eq "t-t") {system("perl plot_files/pdweb.threads/combinable_threads.pl $log1 g1 -1"); $using1 = "1:3";}
elsif($stat1 eq "threads-default-active" || $stat1 eq "t-d-a") {system("perl plot_files/pdweb.threads/combinable_threads.pl $log1 g1 -1"); $using1 = "1:4";}
elsif($stat1 eq "threads-default-total" || $stat1 eq "t-d-t") {system("perl plot_files/pdweb.threads/combinable_threads.pl $log1 g1 -1"); $using1 = "1:5";}
elsif($stat1 eq "usersessidcache-hit" || $stat1 eq "u-h") {system("perl plot_files/pdweb.usersessidcache/combinable_usersessidcache.pl $log1 g1 -1"); $using1 = "1:2";}
elsif($stat1 eq "usersessidcache-miss" || $stat1 eq "u-m") {system("perl plot_files/pdweb.usersessidcache/combinable_usersessidcache.pl $log1 g1 -1"); $using1 = "1:3";}
elsif($stat1 eq "usersessidcache-add" || $stat1 eq "u-a") {system("perl plot_files/pdweb.usersessidcache/combinable_usersessidcache.pl $log1 g1 -1"); $using1 = "1:4";}
elsif($stat1 eq "usersessidcache-del" || $stat1 eq "u-d") {system("perl plot_files/pdweb.usersessidcache/combinable_usersessidcache.pl $log1 g1 -1"); $using1 = "1:5";}
elsif($stat1 eq "usersessidcache-inactive" || $stat1 eq "u-i") {system("perl plot_files/pdweb.usersessidcache/combinable_usersessidcache.pl $log1 g1 -1"); $using1 = "1:6";}
elsif($stat1 eq "usersessidcache-lifetime" || $stat1 eq "u-l") {system("perl plot_files/pdweb.usersessidcache/combinable_usersessidcache.pl $log1 g1 -1"); $using1 = "1:7";}
elsif($stat1 eq "usersessidcache-lru-exp" || $stat1 eq "u-l-e") {system("perl plot_files/pdweb.usersessidcache/combinable_usersessidcache.pl $log1 g1 -1"); $using1 = "1:8";}
elsif($stat1 eq "vhj-reqs" || $stat1 eq "v-r") {system("perl plot_files/pdweb.vhj.#/combinable_vhj.pl $log1 g1 -1"); $using1 = "1:2";}
elsif($stat1 eq "vhj-max" || $stat1 eq "v-m") {system("perl plot_files/pdweb.vhj.#/combinable_vhj.pl $log1 g1 -1"); $using1 = "1:3";}
elsif($stat1 eq "vhj-avg" || $stat1 eq "v-a") {system("perl plot_files/pdweb.vhj.#/combinable_vhj.pl $log1 g1 -1"); $using1 = "1:4";}
elsif($stat1 eq "vhj-total" || $stat1 eq "v-t") {system("perl plot_files/pdweb.vhj.#/combinable_vhj.pl $log1 g1 -1"); $using1 = "1:5";}
else {print "incorrect stat1 input";}

if($stat2 eq "authn-pass" || $stat2 eq "an-p") {system("perl plot_files/pdweb.authn/combinable_authn.pl $log2 g2 0"); $using2 = "1:2";}
elsif($stat2 eq "authn-fail" || $stat2 eq "an-f") {system("perl plot_files/pdweb.authn/combinable_authn.pl $log2 g2 1"); $using2 = "1:3";}
elsif($stat2 eq "authn-pwd-exp" || $stat2 eq "an-p-e") {system("perl plot_files/pdweb.authn/combinable_authn.pl $log2 g2 2"); $using2 = "1:4";}
elsif($stat2 eq "authn-max" || $stat2 eq "an-m") {system("perl plot_files/pdweb.authn/combinable_authn.pl $log2 g2 3"); $using2 = "1:5";}
elsif($stat2 eq "authn-total" || $stat2 eq "an-t") {system("perl plot_files/pdweb.authn/combinable_authn.pl $log2 g2 5"); $using2 = "1:7";}
elsif($stat2 eq "authn-avg" || $stat2 eq "an-a") {system("perl plot_files/pdweb.authn/combinable_authn.pl $log2 g2 4"); $using2 = "1:6";}
elsif($stat2 eq "authz-pass" || $stat2 eq "az-p") {system("perl plot_files/pdweb.authz/combinable_authz.pl $log2 g2 0"); $using2 = "1:2";}
elsif($stat2 eq "authz-fail" || $stat2 eq "az-f") {system("perl plot_files/pdweb.authz/combinable_authz.pl $log2 g2 1"); $using2 = "1:3";}
elsif($stat2 eq "certcallbackcache-hit" || $stat2 eq "c-h") {system("perl plot_files/pdweb.certcallbackcache/combinable_certcallbackcache.pl $log1 g2 0"); $using2 = "1:2";}
elsif($stat2 eq "certcallbackcache-miss" || $stat2 eq "c-m") {system("perl plot_files/pdweb.certcallbackcache/combinable_certcallbackcache.pl $log1 g2 1"); $using2 = "1:3";}
elsif($stat2 eq "certcallbackcache-add" || $stat2 eq "c-a") {system("perl plot_files/pdweb.certcallbackcache/combinable_certcallbackcache.pl $log1 g2 2"); $using2 = "1:4";}
elsif($stat2 eq "certcallbackcache-del" || $stat2 eq "c-d") {system("perl plot_files/pdweb.certcallbackcache/combinable_certcallbackcache.pl $log1 g2 3"); $using2 = "1:5";}
elsif($stat2 eq "certcallbackcache-inactive" || $stat2 eq "c-i") {system("perl plot_files/pdweb.certcallbackcache/combinable_certcallbackcache.pl $log1 g2 4"); $using2 = "1:6";}
elsif($stat2 eq "certcallbackcache-lifetime" || $stat2 eq "c-l") {system("perl plot_files/pdweb.certcallbackcache/combinable_certcallbackcache.pl $log1 g2 5"); $using2 = "1:7";}
elsif($stat2 eq "certcallbackcache-lru-exp" || $stat2 eq "c-l-e") {system("perl plot_files/pdweb.certcallbackcache/combinable_certcallbackcache.pl $log1 g2 6"); $using2 = "1:8";}
elsif($stat2 eq "doccache-general-errors" || $stat2 eq "d-g-e") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g2 0"); $using2 = "1:2";}
elsif($stat2 eq "doccache-uncachable" || $stat2 eq "d-u") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g2 1"); $using2 = "1:3";}
elsif($stat2 eq "doccache-pending-deletes" || $stat2 eq "d-p-d") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g2 2"); $using2 = "1:4";}
elsif($stat2 eq "doccache-pending-size" || $stat2 eq "d-p-s") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g2 3"); $using2 = "1:5";}
elsif($stat2 eq "doccache-misses" || $stat2 eq "d-m") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g2 4"); $using2 = "1:6";}
elsif($stat2 eq "doccache-max-size" || $stat2 eq "d-m-s") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g2 6"); $using2 = "1:8";}
elsif($stat2 eq "doccache-max-entry-size" || $stat2 eq "d-m-e-s") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g2 7"); $using2 = "1:9";}
elsif($stat2 eq "doccache-default-max-age" || $stat2 eq "d-d-m-a") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g2 8"); $using2 = "1:10";}
elsif($stat2 eq "doccache-size" || $stat2 eq "d-s") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g2 9"); $using2 = "1:11";}
elsif($stat2 eq "doccache-count" || $stat2 eq "d-c") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g2 10"); $using2 = "1:12";}
elsif($stat2 eq "doccache-hits" || $stat2 eq "d-h") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g2 11"); $using2 = "1:13";}
elsif($stat2 eq "doccache-stale-hits" || $stat2 eq "d-s-h") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g2 12"); $using2 = "1:14";}
elsif($stat2 eq "doccache-create-waits" || $stat2 eq "d-c-w") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g2 13"); $using2 = "1:15";}
elsif($stat2 eq "doccache-cache-no-room" || $stat2 eq "d-c-n-r") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g2 14"); $using2 = "1:16";}
elsif($stat2 eq "doccache-additions" || $stat2 eq "d-add") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g2 15"); $using2 = "1:17";}
elsif($stat2 eq "doccache-aborts" || $stat2 eq "d-ab") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g2 16"); $using2 = "1:18";}
elsif($stat2 eq "doccache-deletes" || $stat2 eq "d-d") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g2 17"); $using2 = "1:19";}
elsif($stat2 eq "doccache-updates" || $stat2 eq "d-u") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g2 18"); $using2 = "1:20";}
elsif($stat2 eq "doccache-too-big-errors" || $stat2 eq "d-t-b-e") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g2 19"); $using2 = "1:21";}
elsif($stat2 eq "doccache-mt-errors" || $stat2 eq "d-m-e") {system("perl plot_files/pdweb.doccache/combinable_doccache.pl $log1 g2 20"); $using2 = "1:22";}
elsif($stat2 eq "drains-draining-fds" || $stat2 eq "dr-d-ing-f") {system("perl plot_files/pdweb.drains/combinable_drains.pl $log1 g2 0"); $using2 = "1:2";}
elsif($stat2 eq "drains-failed-closes" || $stat2 eq "dr-f-c") {system("perl plot_files/pdweb.drains/combinable_drains.pl $log1 g2 1"); $using2 = "1:3";}
elsif($stat2 eq "drains-failed-selects" || $stat2 eq "dr-f-s") {system("perl plot_files/pdweb.drains/combinable_drains.pl $log1 g2 2"); $using2 = "1:4";}
elsif($stat2 eq "drains-fds-closed-hiwat" || $stat2 eq "dr-f-c-h") {system("perl plot_files/pdweb.drains/combinable_drains.pl $log1 g2 3"); $using2 = "1:5";}
elsif($stat2 eq "drains-fds-closed-flood" || $stat2 eq "dr-f-c-f") {system("perl plot_files/pdweb.drains/combinable_drains.pl $log1 g2 4"); $using2 = "1:6";}
elsif($stat2 eq "drains-timed-out-fds" || $stat2 eq "dr-t-o-f") {system("perl plot_files/pdweb.drains/combinable_drains.pl $log1 g2 5"); $using2 = "1:7";}
elsif($stat2 eq "drains-idle-awakenings" || $stat2 eq "dr-i-a") {system("perl plot_files/pdweb.drains/combinable_drains.pl $log1 g2 6"); $using2 = "1:8";}
elsif($stat2 eq "drains-bytes-drained" || $stat2 eq "dr-b-d") {system("perl plot_files/pdweb.drains/combinable_drains.pl $log1 g2 7"); $using2 = "1:9";}
elsif($stat2 eq "drains-drained-fds" || $stat2 eq "dr-d-ed-f") {system("perl plot_files/pdweb.drains/combinable_drains.pl $log1 g2 8"); $using2 = "1:10";}
elsif($stat2 eq "drains-avg-bytes-drained" || $stat2 eq "dr-a-b-d") {system("perl plot_files/pdweb.drains/combinable_drains.pl $log1 g2 9"); $using2 = "1:11";}
elsif($stat2 eq "http-reqs" || $stat2 eq "h-r") {system("perl plot_files/pdweb.http/combinable_http.pl $log1 g2 0"); $using2 = "1:2";}
elsif($stat2 eq "http-max-worker" || $stat2 eq "h-m-w") {system("perl plot_files/pdweb.http/combinable_http.pl $log1 g2 1"); $using2 = "1:3";}
elsif($stat2 eq "http-avg-worker" || $stat2 eq "h-a-w") {system("perl plot_files/pdweb.http/combinable_http.pl $log1 g2 2"); $using2 = "1:4";}
elsif($stat2 eq "http-total-worker" || $stat2 eq "h-t-w") {system("perl plot_files/pdweb.http/combinable_http.pl $log1 g2 3"); $using2 = "1:5";}
elsif($stat2 eq "http-max-webseal" || $stat2 eq "h-m-web") {system("perl plot_files/pdweb.http/combinable_http.pl $log1 g2 4"); $using2 = "1:6";}
elsif($stat2 eq "http-avg-webseal" || $stat2 eq "h-a-web") {system("perl plot_files/pdweb.http/combinable_http.pl $log1 g2 5"); $using2 = "1:7";}
elsif($stat2 eq "http-total-webseal" || $stat2 eq "h-t-web") {system("perl plot_files/pdweb.http/combinable_http.pl $log1 g2 6"); $using2 = "1:8";}
elsif($stat2 eq "https-reqs" || $stat2 eq "hs-r") {system("perl plot_files/pdweb.https/combinable_https.pl $log1 g2 0"); $using2 = "1:2";}
elsif($stat2 eq "https-max-worker" || $stat2 eq "hs-m-w") {system("perl plot_files/pdweb.https/combinable_https.pl $log1 g2 1"); $using2 = "1:3";}
elsif($stat2 eq "https-avg-worker" || $stat2 eq "hs-a-w") {system("perl plot_files/pdweb.https/combinable_https.pl $log1 g2 2"); $using2 = "1:4";}
elsif($stat2 eq "https-total-worker" || $stat2 eq "hs-t-w") {system("perl plot_files/pdweb.https/combinable_https.pl $log1 g2 3"); $using2 = "1:5";}
elsif($stat2 eq "https-max-webseal" || $stat2 eq "hs-m-web") {system("perl plot_files/pdweb.https/combinable_https.pl $log1 g2 4"); $using2 = "1:6";}
elsif($stat2 eq "https-avg-webseal" || $stat2 eq "h-a-web") {system("perl plot_files/pdweb.https/combinable_https.pl $log1 g2 5"); $using2 = "1:7";}
elsif($stat2 eq "https-total-webseal" || $stat2 eq "hs-t-web") {system("perl plot_files/pdweb.https/combinable_https.pl $log1 g2 6"); $using2 = "1:8";}
elsif($stat2 eq "jct-reqs" || $stat2 eq "j-r") {system("perl plot_files/pdweb.jct.#/combinable_jct.pl $log1 g2 0"); $using2 = "1:2";}
elsif($stat2 eq "jct-max" || $stat2 eq "j-m") {system("perl plot_files/pdweb.jct.#/combinable_jct.pl $log1 g2 1"); $using2 = "1:3";}
elsif($stat2 eq "jct-avg" || $stat2 eq "j-a") {system("perl plot_files/pdweb.jct.#/combinable_jct.pl $log1 g2 2"); $using2 = "1:4";}
elsif($stat2 eq "jct-total" || $stat2 eq "j-t") {system("perl plot_files/pdweb.jct.#/combinable_jct.pl $log1 g2 3"); $using2 = "1:5";}
elsif($stat2 eq "jmt-hits" || $stat2 eq "j-h") {system("perl plot_files/pdweb.jmt/combinable_jmt.pl $log1 g2 0"); $using2 = "1:2";}
elsif($stat2 eq "sescache-hit" || $stat2 eq "s-h") {system("perl plot_files/pdweb.sescache/combinable_sescache.pl $log1 g2 0"); $using2 = "1:2";}
elsif($stat2 eq "sescache-miss" || $stat2 eq "s-m") {system("perl plot_files/pdweb.sescache/combinable_sescache.pl $log1 g2 1"); $using2 = "1:3";}
elsif($stat2 eq "sescache-add" || $stat2 eq "s-a") {system("perl plot_files/pdweb.sescache/combinable_sescache.pl $log1 g2 2"); $using2 = "1:4";}
elsif($stat2 eq "sescache-del" || $stat2 eq "s-d") {system("perl plot_files/pdweb.sescache/combinable_sescache.pl $log1 g2 3"); $using2 = "1:5";}
elsif($stat2 eq "sescache-inactive" || $stat2 eq "s-i") {system("perl plot_files/pdweb.sescache/combinable_sescache.pl $log1 g2 4"); $using2 = "1:6";}
elsif($stat2 eq "sescache-lifetime" || $stat2 eq "s-l") {system("perl plot_files/pdweb.sescache/combinable_sescache.pl $log1 g2 5"); $using2 = "1:7";}
elsif($stat2 eq "sescache-lru-exp" || $stat2 eq "s-l-e") {system("perl plot_files/pdweb.sescache/combinable_sescache.pl $log1 g2 6"); $using2 = "1:8";}
elsif($stat2 eq "threads-active" || $stat2 eq "t-a") {system("perl plot_files/pdweb.threads/combinable_threads.pl $log1 g2 0"); $using2 = "1:2";}
elsif($stat2 eq "threads-total" || $stat2 eq "t-t") {system("perl plot_files/pdweb.threads/combinable_threads.pl $log1 g2 1"); $using2 = "1:3";}
elsif($stat2 eq "threads-default-active" || $stat2 eq "t-d-a") {system("perl plot_files/pdweb.threads/combinable_threads.pl $log1 g2 2"); $using2 = "1:4";}
elsif($stat2 eq "threads-default-total" || $stat2 eq "t-d-t") {system("perl plot_files/pdweb.threads/combinable_threads.pl $log1 g2 3"); $using2 = "1:5";}
elsif($stat2 eq "usersessidcache-hit" || $stat2 eq "u-h") {system("perl plot_files/pdweb.usersessidcache/combinable_usersessidcache.pl $log1 g2 0"); $using2 = "1:2";}
elsif($stat2 eq "usersessidcache-miss" || $stat2 eq "u-m") {system("perl plot_files/pdweb.usersessidcache/combinable_usersessidcache.pl $log1 g2 1"); $using2 = "1:3";}
elsif($stat2 eq "usersessidcache-add" || $stat2 eq "u-a") {system("perl plot_files/pdweb.usersessidcache/combinable_usersessidcache.pl $log1 g2 2"); $using2 = "1:4";}
elsif($stat2 eq "usersessidcache-del" || $stat2 eq "u-d") {system("perl plot_files/pdweb.usersessidcache/combinable_usersessidcache.pl $log1 g2 3"); $using2 = "1:5";}
elsif($stat2 eq "usersessidcache-inactive" || $stat2 eq "u-i") {system("perl plot_files/pdweb.usersessidcache/combinable_usersessidcache.pl $log1 g2 4"); $using2 = "1:6";}
elsif($stat2 eq "usersessidcache-lifetime" || $stat2 eq "u-l") {system("perl plot_files/pdweb.usersessidcache/combinable_usersessidcache.pl $log1 g2 5"); $using2 = "1:7";}
elsif($stat2 eq "usersessidcache-lru-exp" || $stat2 eq "u-l-e") {system("perl plot_files/pdweb.usersessidcache/combinable_usersessidcache.pl $log1 g2 6"); $using2 = "1:8";}
elsif($stat2 eq "vhj-reqs" || $stat2 eq "v-r") {system("perl plot_files/pdweb.vhj.#/combinable_vhj.pl $log1 g2 0"); $using2 = "1:2";}
elsif($stat2 eq "vhj-max" || $stat2 eq "v-m") {system("perl plot_files/pdweb.vhj.#/combinable_vhj.pl $log1 g2 1"); $using2 = "1:3";}
elsif($stat2 eq "vhj-avg" || $stat2 eq "v-a") {system("perl plot_files/pdweb.vhj.#/combinable_vhj.pl $log1 g2 2"); $using2 = "1:4";}
elsif($stat2 eq "vhj-total" || $stat2 eq "v-t") {system("perl plot_files/pdweb.vhj.#/combinable_vhj.pl $log1 g2 3"); $using2 = "1:5";}
else {print "incorrect stat2 input";}

open (MYFILE, '<interval') || die("Cannot Open File");
while(<MYFILE>) {$interval = $_;}

open (MYFILE, '>combined_plot.dem') || die("Cannot Open File");

print MYFILE "#Author. Denis K. Sokolov 11/2010 IBM
#This is a gnu script that will plot pdweb performance stats on gnuplot
#of a combination of two specific statistics from their outputs gnudata_1 and gnudata_2

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
set ytics nomirror
set y2tics 0, $interval

#label axes, title, and legend
set xlabel \"Time\"  
set ylabel \"$label1\"
set y2label \"$label2\"
set title \"$title\"
set key rmargin

#sets reqs output file and plots reqs data to it
set terminal png enhanced size 1280,1024
set output \"$out_plot\.png\"
plot 'gnudata_1' every ::2 using $using1 index 0 axis x1y1 with lines linewidth 2 linetype rgb \"$color1\" title \"$label1\", \\
'gnudata_2' every ::2 using $using2 index 0 axis x1y2 with lines linewidth 2 linetype rgb \"$color2\" title \"$label2\"";

close (MYFILE);

system("gnuplot/binary/gnuplot combined_plot.dem");

system("del gnudata_1");
system("del gnudata_2");
system("del combined_plot.dem");
system("del interval");