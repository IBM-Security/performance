#!/usr/bin/perl

# perfanalyze_adapter.pl
# Author: Casey Peel (cpeel@us.ibm.com)
# Last Updated: 2007/07/12 1113 MDT
# Summary:
#    Analyzes IBM Tivoli Identity Manager adapter logs
# Description:
#    This script reads in the log from an ITIM adapter and shows response times.
#    Full debug logging must be enabled in the ITIM adapter.
#

use Getopt::Std;
use POSIX;

# Debug?
$DEBUG=0;

getopts('i:l:c:srgph') or usage();
usage() if($opt_h);

# Print Usage and exit
sub usage {
   print STDERR <<EOF

Usage: $0 [ -i inputFile ] [ -c <cutoff> | -r | -g | -p ]
Output options:
  -s - show Request timing summary
  -r - show Request timings on a per-thread basis
  -g - show time gap analysis - where time is spent
  -p - show processed time gap analysis
  -l - processing level
          none - don't try to standardize line data
           min - remove DSML response lines (default)
           mid - normalize common log lines
           max - break out the big guns
  -c - cutoff for processed time gap analysis (default: 5)

Other options:
  -h - displays this help information
  -i - file containing log for processing

If no inputFile is given, the program will read input from STDIN.

EOF
;
   exit;
}

# Open an existing file if one is given
if($opt_i) {
   if(-f $opt_i) {
      open INPUT, $opt_i || die("Unable to open file $opt_i\n");
      $fileHandle=*INPUT;
   } else {
      die("Unable to open file $opt_i\n");
   }
}

# Default input is STDIN
if(!$fileHandle) {
   print STDERR "no input file specified (-i), reading input from STDIN\n";
   print STDERR "Hint: use the -h option to get the usage statement\n";
   $fileHandle=*STDIN;
}

# set some defaults
$cutoff=5;
$starttime=$endtime=0;
$totalDuration=0;
$processLevel=1;

# load command-line options
$cutoff=$opt_c if($opt_c ne "");

$processLevel=0 if($opt_l eq "none");
$processLevel=1 if($opt_l eq "min");
$processLevel=5 if($opt_l eq "mid");
$processLevel=10 if($opt_l eq "max");

# make sure at least one of the display options is used
if(!$opt_s && !$opt_r && !$opt_g && !$opt_p) {
   $opt_s=1;
}

while($line=<$fileHandle>) {
   chomp($line);
   $line=~s/\r//g;

   print "DEBUG: $line\n" if($DEBUG);
   if($line=~m#(\d+)/(\d+)/(\d+) (\d+):(\d+):(\d+)#) {
      $year=$1;
      $year=2000-$year if($year>100);
      $timestamp=mktime($6,$5,$4,$3,$2-1,$year);
   }

   $endtime=$timestamp;

   if($line=~/Thread:(\d+)/) {
      $thread=$1;
      $seenThread{$1}=1;
      $newTimestamp{$thread}=$timestamp;
      $holdTimestamp{$thread}=$timestamp if(!$holdTimestamp{$thread});
      if($newTimestamp{$thread} ne $holdTimestamp{$thread}) {
         push @{$problemLines{$thread}}, $holdLine{$thread} if($holdLine{$thread} ne "");
         push @{$followerLines{$thread}}, $line;
         $holdTimestamp{$thread}=$newTimestamp{$thread};
      }
      $holdLine{$thread}=$line;
   }

   if($line=~m#<(\w+)Request# && $line!~m#BindRequest#) {
      $starttime=$timestamp if($starttime==0);
      $action=$1;
      $tempHash{"$thread:$action"}=$timestamp;
   }

   if($line=~m#<(\w+)Response# && $line!~m#BindResponse#) {
      $action=$1;
      $duration=$timestamp-$tempHash{"$thread:$action"};
      $actionDuration{$action}+=$duration;
      $actionCount{$action}++;
      $totalDuration+=$duration;
      undef $tempHash{"$thread:$action"};
      print "Action: $action, Thread: $thread, Duration: $duration seconds\n" if($opt_r);
   }
}

@threadList=sort keys %seenThread;
$threadCount=scalar @threadList;

if($opt_s) {
   $totalTime=$endtime-$starttime;
   print "Summary:\n";
   print "   Total threads: $threadCount\n";
   print "   Actions:\n";
   foreach $action (sort keys %actionDuration) {
      $avgDuration=$actionDuration{$action}/$actionCount{$action};
      print "      $action - num: $actionCount{$action}, total duration: $actionDuration{$action}, avg duration: $avgDuration\n";
   }
   print "   Total time from first to last action: $totalTime seconds\n";
   print "   Total duration from all actions: $totalDuration seconds\n";
}

if($opt_g) {
   print "Time-gap analysis grouped by thread:\n";
   # now print one thread at a time
   foreach $thread (sort keys %problemLines) {
      $numThreads++;
      print " Thread: $thread\n";
      foreach $problemLine (@{$problemLines{$thread}}) {
         $followerLine=shift @{$followerLines{$thread}};
         print "  $problemLine\n";
         print "  $followerLine\n";
         print "  -------------------------\n";
      }
   }
}


# try to do some smart processing to find common lines
if($opt_p) {
   foreach $thread (sort keys %problemLines) {
      foreach $line (@{$problemLines{$thread}}) {
         # do basic normalization
         $line=~s/^.*Thread:\d+ //;
         $line=~s/^\s+$//;

         # min
         if($processLevel>0) {
            # skip DAML lines
            next if($line=~/^\d\d\d\. /);
            next if($line=~/^-+$/);
         }

         # mid
         if($processLevel>=5) {
            $line=~s/ \d+ of \d+ (bytes)/ ##### of ##### $1/i;
            $line=~s/ \d+ (bytes)/ ##### $1/i;
            $line=~s/(payload =) \d+ /$1 ##### /i;
            $line=~s/(Thread count:) \d+/$1 #####/i;
         }

         # max
         if($processLevel>=10) {
            $line=~s/(Processing \w+ request for) .*/$1 STRING/i;
            $line=~s/(Generated \w+:) .*/$1 STRING/i;
            $line=~s/(User DN:) .*/$1 STRING/i;
         }

         next if($line=~/^$/);

         $commonLines{$line}++;
      }
   }

   # create sorted list
   @sortedList = sort { $commonLines{$a} <=> $commonLines{$b} } keys %commonLines;

   print "Time-gap analysis process results:\n";
   print "  Skipping lines that occured fewer than $cutoff times...\n" if($cutoff>0);
   print "numOccur  line\n";
   foreach $line (@sortedList) {
      next if($commonLines{$line} < $cutoff);

      printf "%8d  %s\n", $commonLines{$line}, $line;
   }
}


# vim: sw=3 ts=3 expandtab
