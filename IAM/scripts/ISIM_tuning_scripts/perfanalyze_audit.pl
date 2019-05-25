#!/usr/bin/perl

# perfanalyze_audit.pl
# Author: Casey Peel (cpeel@us.ibm.com)
# CoAuthor: Dave Bachmann (bachmann@us.ibm.com)
# CoAuthor: Nnaemeka Emejulu (eemejulu@us.ibm.com)
# Last Updated: 2019/05/024 1634 CDT
# Summary:
#    Analyzes IBM Tivoli Directory Server audit logs and SunONE access logs
# Description:
#    This script reads in an ITDS audit log or SunONE access log
#    and prints out five different reports:
#       * Filter timings report - identifies long-running queries
#       * Filter distribution report - shows the timing distribution for queries
#       * Transaction summary - reports all transaction percentages
#       * Time interval report - gives a list of how many searches were done
#           in a given timeframe (not available with SunONE access logs)
#       * Filter frequency report - reports which filters are seen most
#           frequently
#
#    This takes an ITDS audit log or SunONE access log as input.
#    See the ITDS documentation for enabling the audit log.
#

use Getopt::Std;
use POSIX;
use strict;

# DEBUG?
our $DEBUG=0;

our %options;

getopts('i:o:f:c:m:r:ahtgsdbpluv', \%options) or usage();
usage() if($options{h});

# Print Usage and exit
sub usage {
   print STDERR <<EOF

Usage: $0 [ -i inputFile ] [ -o outputFile ] [ -f filterMethod ] [ -t [ -c cutOff ] | -gsdbplauv | -m timeFrame ] 
Filter options:
  -f - filter method, the following options are valid:
           all - all filters, don't collect similar filters
         fuzzy - use fuzzy filters (ie: no attribute values), default
          full - use full filters

Sort options:
  -r - sort options for use with filter timings report (-t) and
       add/modify/delete report (-u)
          secPerExec - seconds per execution, default
             numExec - number of executions
              filter - filter (-t report only)
              stdDev - standard deviation (-t report only)
             aggTime - aggregate time of searches (-t report only)
               entry - entry (-u report only)

Output options
  -t - show search filter timings
  -u - show add/modify/delete timings
  -d - show search distribution timings
  -s - show transaction summary
  -g - show search filter frequencies
  -m - show time-interval stats, timeFrame is one of:
       second, minute, hour, day, month
  -c - statements longer than this time are not included in timings report,
       default is 0.1
  -v - show standard deviation
  -b - show search bases
  -p - show search scopes
  -l - show control types (like server-side sorts)
  -a - show aggregate timings

Other options:
  -h - displays this help information
  -i - file containing log for processing
  -o - file to put the processed results in, default is STDOUT

If no inputFile is given, the program will read input from STDIN.

EOF
;
   exit;
}

# if they run it without options, assume timing report
if(!$options{t} && !$options{g} && !$options{s} && !$options{d} && !$options{m} && !$options{u}) {
   $options{t}=1;
}

# Initialize options
our $filterMethod="fuzzy";

our $showTimings=0;
our $showFrequencies=0;
our $showSummary=0;
our $showDistribution=0;
our $showTimeFrame="";
our $cutoff=0.1;
our $showStdDeviation=0;
our $showBases=0;
our $showScopes=0;
our $showControlTypes=0;
our $showAggregateTiming=0;
our $showCRUDTimings=0;
our $sortColumn='secPerExec';

$filterMethod=$options{f} if($options{f});
$showTimings=$options{t} if($options{t});
$showFrequencies=$options{g} if($options{g});
$showSummary=$options{s} if($options{s});
$showDistribution=$options{d} if($options{d});
$cutoff=$options{c} if($options{c} ne "");
$showStdDeviation=$options{v} if($options{v});
$showTimeFrame=$options{m} if($options{m});
$showBases=$options{b} if($options{b});
$showScopes=$options{p} if($options{p});
$showControlTypes=$options{l} if($options{l});
$showAggregateTiming=$options{a} if($options{a});
$showCRUDTimings=$options{u} if($options{u});
$sortColumn=$options{r} if($options{r});

# ensure the sort column is visible
$showAggregateTiming=1 if($sortColumn eq "aggTime");

if($filterMethod eq "all" && $showFrequencies) {
   warn("A frequency report (-g) with the 'all' filter option (-f all) isn't going to get you what you want since by definition the 'all' option shows every single query so each would have a frequency of 1. I'm setting your filter option to 'full' instead.\n");
   $filterMethod="full";
}

# there's also no point in calculating or showing standard deviation for the 'all' filter option
if($filterMethod eq "all" && $showStdDeviation) {
   $showStdDeviation=0;
}

# evaluate if we need to do any extra checks or if this is a "plain Jane" instance
# this makes processing a bit faster for the default case
our $doExtraChecks=0;
$doExtraChecks=1 if($showBases || $showScopes || $showControlTypes || $showStdDeviation || $showTimeFrame);

# Default input is STDIN and output is STDOUT
our $outputFileHandle=*STDOUT;
our $inputFileHandle;

# Open an existing file if one is given
if($options{i}) {
   if(-f $options{i}) {
      open INPUT, $options{i} || die("Unable to open file $options{i}\n");
      $inputFileHandle=*INPUT;
   } else {
      die("Unable to open file $options{i}\n");
   }
}

# Default input is STDIN
if(!$inputFileHandle) {
   print STDERR "no input file specified (-i), reading input from STDIN\n";
   print STDERR "Hint: use the -h option to get the usage statement\n";
   $inputFileHandle=*STDIN;
}

# Open the file to put the output in, if necessary
if($options{o}) {
   open OUTPUT, ">$options{o}" || die("Unable to open $options{o} for writing\n");
   $outputFileHandle=*OUTPUT;
}

# set up summary counters
our %transCount;
$transCount{"bind"}=0;
$transCount{"unbind"}=0;
$transCount{"search"}=0;
$transCount{"add"}=0;
$transCount{"modify"}=0;
$transCount{"delete"}=0;

our %baseHash;
our %scopeHash;
our %filterCount;
our %aggregateTimeHash;
our %timeFrameHash;
our %sssHash;
our %pagingHash;
our %stdDev;
our %crudHash;
our %crudCount;

# global variables for ITDS processing
our $baseTimeString="";
our $baseTime=0;
our $timeRegex=qr/--(\d\d\d\d-\d\d-\d\d-\d\d):(\d\d):(\d\d)(\.\d\d\d).+received: (\d\d\d\d-\d\d-\d\d-\d\d):(\d\d):(\d\d)(\.\d\d\d)/;
our $timeRegex631=qr/--(\d\d\d\d-\d\d-\d\dT\d\d):(\d\d):(\d\d)(\.\d\d\d).+received: (\d\d\d\d-\d\d-\d\dT\d\d):(\d\d):(\d\d)(\.\d\d\d)/;
our $filterRegex=qr/(?m)^filter: (.+)[\r]*$/;
our $entryRegex=qr/(?m)^entry: (.+)[\r]*$/;
our $objectRegex=qr/(?m)^object: (.+)[\r]*$/;

# global variables for SunONE processing
my %sunOne;


# detect if the input file is an ITDS audit log or a SunONE access log
# by looking at the first line. If it contains a "conn=\d+" string we'll
# assume that its a SunONE log. By default we assume its an ITDS audit log
our $auditFileType="ITDS";
# get the first line of the input
my $firstLine=<$inputFileHandle>;
$auditFileType="SunONE" if($firstLine=~/conn=\d+/);

# recordCount is used for a simple progress meter
my $recordCount=0;

# print status indicator
print STDERR "processing $auditFileType log";

# Note that for ITDS this outer loop handles finding a whole "unit" of
# work and passes that into the function whereas we send every line
# to the SunONE function. This is primarily because ITDS writes the
# entire entry to the audit file after the search completes whereas
# SunONE writes two entries for each search: the request and the result
if($auditFileType eq "ITDS") {
   # setting $/ = "AuditV" will pull out one stanza at a time from the file
   # with the limitation that the AuditV from the next statement will appear
   # at the end of the previous one. Given that we don't ever match on AuditV
   # this limitation isn't a problem here.
   local $/ = "AuditV";

   # handle the special case of the firstLine we used to identify the
   # file type
   my $stanza=$firstLine . <$inputFileHandle>;
   processITDSStanza($stanza);

   while($stanza=<$inputFileHandle>) {
      $recordCount++;
      print STDERR "." if(!($recordCount % 10000));
      processITDSStanza($stanza);
   }

   # read in the very last stanza and process it
   local $/ = undef;
   $stanza.=<$inputFileHandle>;
   processITDSStanza($stanza) if($stanza);

} elsif($auditFileType eq "SunONE") {
   # disable any requested reporting options that we don't support
   # from data in the SunONE access logs
   $showTimeFrame=0;
   $showControlTypes=0;

   processSunONELine($firstLine);

   while(my $line=<$inputFileHandle>) {
      $recordCount++;
      print STDERR "." if(!($recordCount % 20000));
      processSunONELine($line);
   }

   print STDERR "unmatched records: " . scalar(keys %sunOne) if(scalar(keys %sunOne));

   if($DEBUG && scalar(keys %sunOne)) {
      print STDERR "DEBUG: unmatched records:\n";
      foreach my $line (sort values %sunOne) {
         print STDERR "DEBUG:   $line";
      }
   }
}

print STDERR "\n";

sub processSunONELine {
   my ($line) = @_;

   $line=~s/\r//g;

   # we assume that the connection, operation, and message ID
   # constitute a single transaction to map the query request
   # with the resulting time
   my $hashKey;
   if($line=~/conn=(\d+) op=(\d+) msgId=(\d+)/) {
      $hashKey="$1-$2-$3";
   } else {
      return;
   }

   # if a matching result (either RESULT or ABANDON) as an etime, processit
   my $time;
   if($line=~/etime=(\d+\.*\d*)/ && $sunOne{$hashKey}) {
      $time=$1;
      $line=$sunOne{$hashKey};
      delete $sunOne{$hashKey};
   }
   # if its an ABANDON without an etime, remove any matching search from
   # the result set
   elsif($line=~/ABANDON/) {
      # if there was a matching search result, nuke it
      delete $sunOne{$hashKey};
      return;
   }
   # if its an UNBIND we'll process that now too since it won't have any
   # matching RESULT line
   elsif($line=~/UNBIND/) {
      # fall through
   }
   # if it isn't, we'll store the line with the connection info
   # and return
   else {
      $sunOne{$hashKey}=$line;
      return;
   }

   # now the actual processing happens

   if($line=~/SRCH/) {
      $transCount{"search"}++;

      # get the filter
      my $filter;
      $filter=$1 if($line=~/filter="(.*?)" /);

      if($filterMethod eq "fuzzy") {
         $filter=~s/=[^)]+/=/g;
      } elsif($filterMethod eq "all") {
         $filter="$hashKey--$filter";
      }

      # save the base and scope per filter
      if($showBases && $line=~/ base="(.*?)" /) {
         $baseHash{$filter}{$1}++;
      }
      if($showScopes && $line=~/ scope=(.*?) /) {
         $scopeHash{$filter}{$1}++;
      }

      # count the number of times we've seen this filter
      $filterCount{$filter}++;

      # add up the total time for this filter
      $aggregateTimeHash{$filter}+=$time;

      undef $filter;
      undef $time;
   } elsif($line=~/ BIND/) {
      $transCount{"bind"}++;
   } elsif($line=~/ UNBIND/) {
      $transCount{"unbind"}++;
   } elsif($line=~/ ADD/) {
      $transCount{"add"}++;
   } elsif($line=~/ MOD/) {
      $transCount{"modify"}++;
   } elsif($line=~/ DEL/) {
      $transCount{"delete"}++;
   }
}


sub processITDSStanza {
   my ($stanza) = @_;
   my ($filter, $time, $controlType);

   # calling mktime twice for every stanza is a major perf hit
   # hence the baseTime stuff below which is roughly 2x faster
   # for stanzas tightly-clustered in time (specifically hours)
   my $startTime;
   if($stanza=~/$timeRegex/) {
      if($baseTimeString ne $5) {
         $baseTimeString=$5;
         my($year,$month,$day,$hour)=split("-", $baseTimeString);
         $baseTime=mktime(0,0,$hour,$day,$month,$year-1900);
      }
      $startTime=$baseTime+($6*60)+$7+$8;

      if($baseTimeString ne $1) {
         $baseTimeString=$1;
         my($year,$month,$day,$hour)=split("-", $baseTimeString);
         $baseTime=mktime(0,0,$hour,$day,$month,$year-1900);
      }
      $time=($baseTime+($2*60)+$3+$4) - $startTime;
   }
   if($stanza=~/$timeRegex631/) {
      if($baseTimeString ne $5) {
         $baseTimeString=$5;
        
         my($year,$month,$dayThour)=split("-", $baseTimeString);
         my($day,$hour)=split("T", $dayThour);
         $baseTime=mktime(0,0,$hour,$day,$month,$year-1900);
      }
      $startTime=$baseTime+($6*60)+$7+$8;

      if($baseTimeString ne $1) {
         $baseTimeString=$1;
         #my($year,$month,$day,$hour)=split("-", $baseTimeString);
         #$baseTime=mktime(0,0,$hour,$day,$month,$year-1900);
         my($year,$month,$dayThour)=split("-", $baseTimeString);
         my($day,$hour)=split("T", $dayThour);
         $baseTime=mktime(0,0,$hour,$day,$month,$year-1900);
      }
      $time=($baseTime+($2*60)+$3+$4) - $startTime;
   }

   # now begin processing the new stanza
   # add it to our counts for various operations
   if(index($stanza," Search--") >=0 ) {
      $transCount{"search"}++;

      # get the filter
      $filter=$1 if($stanza=~/$filterRegex/);

      if($filterMethod eq "fuzzy") {
         $filter=~s/=[^)]+/=/g;
      } elsif($filterMethod eq "all") {
         $filter="$startTime--$filter";
      }

      # count the number of times we've seen this filter
      $filterCount{$filter}++;

      # add up the total time for this filter
      $aggregateTimeHash{$filter}+=$time;

      # bypass any extra checks if we're running in "plain Jane" mode
      if($doExtraChecks) {
         # remove any carriage returns that might exist before doing
         # additional regex's to pull data out
         $stanza=~s/\r//g;

         # if they want timeframe info, calculate our hash key
         if($showTimeFrame) {
            $stanza=~/received: (\d\d\d\d)-(\d\d)-(\d\d)-(\d\d):(\d\d):(\d\d)/;

            my $timeFrameKey;
            if($showTimeFrame eq "second") {
               $timeFrameKey="$1-$2-$3 $4:$5:$6";
            } elsif($showTimeFrame eq "minute") {
               $timeFrameKey="$1-$2-$3 $4:$5";
            } elsif($showTimeFrame eq "hour") {
               $timeFrameKey="$1-$2-$3 $4";
            } elsif($showTimeFrame eq "day") {
               $timeFrameKey="$1-$2-$3";
            } elsif($showTimeFrame eq "month") {
               $timeFrameKey="$1-$2";
            }

            # add up the total time for this timeframe
            $timeFrameHash{$timeFrameKey}++;
         }

         # save the base and scope per filter
         if($showBases && $stanza=~/^base: (.*)$/mi) {
            $baseHash{$filter}{$1}++;
         }
         if($showScopes && $stanza=~/^scope: (.*)$/mi) {
            $scopeHash{$filter}{$1}++;
         }

         # save controlTypes
         if($showControlTypes && $stanza=~/^controlType: (.*)$/mi) {
            $controlType=$1;
            if($controlType=~/1.2.840.113556.1.4.473/) {
               $sssHash{$filter}++;
            }
            if($controlType=~/1.2.840.113556.1.4.319/) {
               $pagingHash{$filter}++;
            }
         }

         if($showStdDeviation) {
            # using Algorithm III from http://en.wikipedia.org/wiki/Algorithms_for_calculating_variance
            # here we're calculating just the variance
            $stdDev{$filter}{"delta"}=$time-$stdDev{$filter}{"mean"};
            $stdDev{$filter}{"mean"}+=$stdDev{$filter}{"delta"}/$filterCount{$filter};
            $stdDev{$filter}{"S"}+=$stdDev{$filter}{"delta"}*($time-$stdDev{$filter}{"mean"});
         }
      }
   } elsif(index($stanza," Add--") >= 0) {
      $transCount{"add"}++;

      # get the entry
      my $entry=$1 if($stanza=~/$entryRegex/);
      $crudHash{"ADD: $entry"}+=$time;
      $crudCount{"ADD: $entry"}++;
   } elsif(index($stanza," Modify--") >= 0) {
      $transCount{"modify"}++;

      # get the object
      my $object=$1 if($stanza=~/$objectRegex/);
      $crudHash{"MODIFY: $object"}+=$time;
      $crudCount{"MODIFY: $object"}++;
   } elsif(index($stanza," Bind--") >= 0) {
      $transCount{"bind"}++;
   } elsif(index($stanza," Unbind--") >= 0) {
      $transCount{"unbind"}++;
   } elsif(index($stanza," Delete--") >= 0) {
      $transCount{"delete"}++;

      # get the entry
      my $entry=$1 if($stanza=~/$entryRegex/);
      $crudHash{"DELETE: $entry"}+=$time;
      $crudCount{"DELETE: $entry"}++;
   }
}


my %filterTime;
if($filterMethod ne "all") {
   # create the filter averages
   foreach my $filter (keys %aggregateTimeHash) {
      $filterTime{$filter}=$aggregateTimeHash{$filter}/$filterCount{$filter};
      if($showStdDeviation) {
         # change the variance to standard deviation
         if($filterCount{$filter}>1) {
            $stdDev{$filter}=sqrt($stdDev{$filter}{"S"}/($filterCount{$filter} - 1));
         } else {
            $stdDev{$filter}=0;
         }
      }
   }
} else {
   %filterTime=%aggregateTimeHash;
   undef %aggregateTimeHash if(!$showAggregateTiming);
}


# file has been processed, now display requested information
#--------------------------------------------------------------------------------------------

if($showTimings) {
   print $outputFileHandle "\nSearch timing results:\n";
   print $outputFileHandle "  Total records: $recordCount\n";
   print $outputFileHandle "  Skipping queries that executed in less than $cutoff second...\n";   

   if($showControlTypes) {
      print $outputFileHandle "  sss = server-side sorts\n";
      print $outputFileHandle "  paging = paging results\n";
   }
   print $outputFileHandle "  secPerExec numExec";
   print $outputFileHandle "   stdDev" if($showStdDeviation);
   print $outputFileHandle "   aggTime" if($showAggregateTiming);
   print $outputFileHandle " sss paging" if($showControlTypes);
   print $outputFileHandle " filter\n";
   
   # create a sorted list of the filters
   my @sortedList;
   if($sortColumn eq "numExec") {
      @sortedList = sort { $filterCount{$a} <=> $filterCount{$b} } keys %filterCount;
   } elsif($sortColumn eq "aggTime") {
      @sortedList = sort { $aggregateTimeHash{$a} <=> $aggregateTimeHash{$b} } keys %aggregateTimeHash;
   } elsif($sortColumn eq "stdDev") {
      @sortedList = sort { $stdDev{$a} <=> $stdDev{$b} } keys %stdDev;
   } elsif($sortColumn eq "filter") {
      @sortedList = sort keys %filterTime;
   } else {
      @sortedList = sort { $filterTime{$a} <=> $filterTime{$b} } keys %filterTime;
   }

   # print out the filters
   foreach my $filter (@sortedList) {
      next if($filterTime{$filter} < $cutoff);
      
      my $displayFilter=$filter;
      $displayFilter=~s/^.*--// if($filterMethod eq "all");

      printf $outputFileHandle "  %10.5f%8d", $filterTime{$filter}, $filterCount{$filter};
      if($showStdDeviation) {
         printf $outputFileHandle "%9.3f", $stdDev{$filter};
      }
      if($showAggregateTiming) {
         printf $outputFileHandle "%10.4f", $aggregateTimeHash{$filter};
      }
      if($showControlTypes) {
         my $sss = $sssHash{$filter} || "";
         printf $outputFileHandle "%4s", $sss;
         my $paging = $pagingHash{$filter} || "";
         printf $outputFileHandle "%7s", $paging;
      }
      printf $outputFileHandle " $displayFilter\n";
      if($showBases) {
         foreach my $base (sort keys %{$baseHash{$filter}}) {
            printf $outputFileHandle "  %10s%8s base: %s (%d)\n", "", "", $base, $baseHash{$filter}{$base};
         }
      }
      if($showScopes) {
         foreach my $scope (sort keys %{$scopeHash{$filter}}) {
            printf $outputFileHandle "  %10s%8s scope: %s (%d)\n", "", "", $scope, $scopeHash{$filter}{$scope};
         }
      }
   }
}


if($showCRUDTimings) {
   print $outputFileHandle "\nAdd/Modify/Update timing results:\n";
   print $outputFileHandle <<EOF
        Adds: $transCount{"add"}
    Modifies: $transCount{"modify"}
     Deletes: $transCount{"delete"}
EOF
;
   print $outputFileHandle "  secPerExec numExec";
   print $outputFileHandle " entry\n";
   
   # create a sorted list of the filters
   my @sortedList;
   if($sortColumn eq "numExec") {
      @sortedList = sort { $crudCount{$a} <=> $crudCount{$b} } keys %crudCount;
   } elsif($sortColumn eq "entry") {
      @sortedList = sort keys %crudHash;
   } else {
      @sortedList = sort { $crudHash{$a} <=> $crudHash{$b} } keys %crudHash;
   }

   # print out the entries
   foreach my $entry (@sortedList) {
      printf $outputFileHandle "  %10.5f%8d", $crudHash{$entry}, $crudCount{$entry};
      printf $outputFileHandle " $entry\n";
   }
}


if($showDistribution) {
   my @distributionBuckets=(0.001, 0.01, 0.1, 1, 2, 5, 10, 100);
   my %bucketHash;
   my $searchCount=0;
   foreach my $bucket (@distributionBuckets) {
      $bucketHash{$bucket}=0;
   }
   $bucketHash{"more"}=0;
   
   foreach my $filter (sort keys %filterTime) {
      my $foundBucket=0;
      foreach my $bucket (@distributionBuckets) {
         if($filterTime{$filter}<=$bucket) {
            $bucketHash{$bucket}+=$filterCount{$filter};
            $foundBucket=1;
            last;
         }
      }
      if(!$foundBucket) {
         $bucketHash{"more"}+=$filterCount{$filter};
      }
      $searchCount+=$filterCount{$filter};
   }

   print $outputFileHandle "\nSearch Distribution:\n";
   print $outputFileHandle "  Total records: $recordCount\n";
   print $outputFileHandle "  Total searches: $searchCount\n";
   printf $outputFileHandle "  %-10s   %8s   %s   %s\n", "time", "count", "% searches", "% operations";
   my $bucketSearchPercent;
   my $bucketPercent;
   foreach my $bucket (@distributionBuckets) {
      $bucketSearchPercent=sprintf("%6.2f%%",$bucketHash{$bucket}*100/$searchCount);
      $bucketPercent=sprintf("%6.2f%%",$bucketHash{$bucket}*100/$recordCount);
      printf $outputFileHandle "  <= %7.3f   %8d     %s     %s\n",$bucket,$bucketHash{$bucket},$bucketSearchPercent,$bucketPercent;
   }
   $bucketSearchPercent=sprintf("%6.2f%%",$bucketHash{"more"}*100/$searchCount);
   $bucketPercent=sprintf("%6.2f%%",$bucketHash{"more"}*100/$recordCount);
   printf $outputFileHandle "   > %7.3f   %8d     %s     %s\n",$distributionBuckets[(scalar @distributionBuckets)-1],$bucketHash{"more"},$bucketSearchPercent,$bucketPercent;
   
}


if($showSummary) {
   $transCount{"read"}=$transCount{"bind"}+$transCount{"search"};
   $transCount{"write"}=$transCount{"add"}+$transCount{"modify"}+$transCount{"delete"};
   $transCount{"total"}=$transCount{"bind"}+$transCount{"unbind"}+$transCount{"search"}+$transCount{"add"}+$transCount{"modify"}+$transCount{"delete"};

   # caluclate percentages
   foreach my $trans (split ' ', "read write bind unbind search add modify delete") {
      $transCount{"$trans-percent"}=sprintf("%2.2f%%",(($transCount{$trans}*100)/$transCount{"total"}));
   }
   
   print $outputFileHandle <<EOF

Transaction summary:
  Total: $transCount{"total"}
  Overview:
       Reads: $transCount{"read"}  ($transCount{"read-percent"}) - includes binds and searches
      Writes: $transCount{"write"}  ($transCount{"write-percent"}) - includes adds, modifies, and deletes
  Detail:
       Binds: $transCount{"bind"}  ($transCount{"bind-percent"})
     Unbinds: $transCount{"unbind"}  ($transCount{"unbind-percent"})
    Searches: $transCount{"search"}  ($transCount{"search-percent"})
        Adds: $transCount{"add"}  ($transCount{"add-percent"})
    Modifies: $transCount{"modify"}  ($transCount{"modify-percent"})
     Deletes: $transCount{"delete"}  ($transCount{"delete-percent"})
EOF
;
}


if($showTimeFrame) {
   print $outputFileHandle "\nTime Interval Report ($showTimeFrame):\n";
   printf $outputFileHandle "  %-20s  %10s  %-10s\n", "time interval", "count","percent";
   
   foreach my $timeFrame (sort keys %timeFrameHash) {
      printf $outputFileHandle "  %-20s  %10d  %6.2f%%\n", $timeFrame, $timeFrameHash{$timeFrame}, ($timeFrameHash{$timeFrame}*100/$recordCount);
   }
}


if($showFrequencies) {
   my %filterHistogram;
   # build frequency hash, each frequency gets its own 'bucket'
   foreach my $filter (sort keys %filterCount) {
      my $displayFilter=$filter;
      $displayFilter=~s/^.*--// if($filterMethod eq "all");
      push @{$filterHistogram{$filterCount{$filter}}}, $displayFilter;
   }

   print $outputFileHandle "\nFilter Frequencies:\n";
   foreach my $freq (sort {$a <=> $b} keys %filterHistogram) {
      my $freqPercent=sprintf("%.2f",($freq*100)/$recordCount);
      print $outputFileHandle "$freq ($freqPercent%):\n";
      foreach my $filter (sort @{$filterHistogram{$freq}}) {
         print $outputFileHandle "   $filter\n";
      }
   }
}

# vim: sw=3 ts=3 expandtab
