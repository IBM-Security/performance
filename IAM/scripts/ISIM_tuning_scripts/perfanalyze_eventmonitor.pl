#!/usr/bin/perl

# perfanalyze_eventmonitor.pl
# Author: Casey Peel (cpeel@us.ibm.com)
# Last Updated: 2008/03/24 0943 MDT
# Summary:
#    Analyzes DB2 event monitor text files for problem queries
# Description:
#    This script analyses the event monitor output DB2 (it needs
#    to have already been processed by db2evfmt) and gives an
#    analysis for long-running queries.
#

use Getopt::Std;

# Debug?
$DEBUG=0;

getopts('i:d:f:o:t:c:r:hsnw') or usage();
usage() if($opt_h);

# Print Usage and exit
sub usage {
   print STDERR <<EOF

Usage: $0 [ -i inputFile ] [ -o outputFile ] [ -c cutOff | -t truncLine ] [ -w | -n ]
Filter options:
  -f - filter method, the following options are valid:
         fuzzy - use fuzzy filters (ie: no attribute values), default
          full - use full filters
           all - show all filters, no averaging

Output options:
  -t - length to truncate statement at, default is 80 characters. 0 = don't truncate.
  -c - time cutoff; statements longer than this time are not included, default is 0.1
  -r - column to sort by, default is secPerExec
  -n - include queries that have no statistics information
  -w - include the number of rows written

Other options:
  -i - file containing dynamic sql statements for processing
  -o - file to put the processed results in, default is STDOUT


If no arguments are given, the program will read input from STDIN.

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

# Default output file is STDOUT
$outputFileHandle=*STDOUT;

# Unbuffer $outputFileHandle
select((select($outputFileHandle), $|=1)[0]);

# Open the file to put the output in, if necessary
if($opt_o) {
   open OUTPUT, ">$opt_o" || die("Unable to open $opt_o for writing\n");
   $outputFileHandle=*OUTPUT;
}

# set defaults
$filterMethod="fuzzy";
$timeCutoff=0.1;
$statementTruncateLength=80;
$sortColumn='secPerExec';
$includeNAStats=0;
$includeRowsWritten=0;

# get the command-line options if specified
$filterMethod=$opt_f if($opt_f ne "");
$statementTruncateLength=$opt_t if($opt_t ne "");
$timeCutoff=$opt_c if($opt_c ne "");
$sortColumn=$opt_r if($opt_r);
$includeNAStats=1 if($opt_n ne "");
$includeRowsWritten=1 if($opt_w ne "");

# print status indicator
print STDERR "processing snapshot";

%queryHash = {};

$searchCount=0;
$stanza="";
while($line=<$fileHandle>) {
   $line=~s/\r//g;
   # we found the start to a stanza, process the previous one
   if($line=~/^\d+\) Statement/) {
      $searchCount++;
      print STDERR "." if(!($searchCount % 1000));
      processStanza($stanza);
      $stanza="";
   }
   $stanza.=$line;
}

if($stanza) { processStanza($stanza); }

sub processStanza {
   my ($stanza) = @_;

   # get the statement
   if($stanza=~/^\s+Text\s+:\s+(.*?)\s+-+/smi) {
      $statement=$1;
      # a little statement normalization
      $statement=~s#[\r\n]+# #g;
      $statement=~s#^(.*?)\s+(\s.*')#$1$2#g;
      $statement=~s#('.*\s)\s+(.*?)$#$1$2#g;
   }

   # only process stanzas for Close operations for SELECT statements,
   # otherwise we'll get the prepares which aren't that useful
   return if($stanza!~/Operation:\s+Close/mi && $statement=~/^select/i);

   # if statement is empty, skip this stanza
   return if(!$statement);

   # get other data
   $totalExecTime=$1 if($stanza=~/^\s+(?:Exec Time|Elapsed Execution Time):\s+(\d+\.\d+)/mi);
   $rowsWritten=$1 if($stanza=~/^\s+Rows written:\s+(\d+)/mi);

   if($filterMethod eq "fuzzy") {
      # digits
      $statement=~s#(\s*=\s*)\d+#\1NUM#g;
      # strings
      $statement=~s#(\s*=\s*)'[^']*'#\1STRING#g;
      $statement=~s#(\s*=\s*)"[^']*"#\1STRING#g;
   }

   if($filterMethod eq "all") {
      $startTime=$1 if($stanza=~/Start Time: (.*)$/m);
      $statementKey="$startTime--$statement";
   } else {
      $staementKey=$statement;
   }

   $queryHash{$statementKey}{'statement'}=$statement;
   $queryHash{$statementKey}{'numExec'}++;
   $queryHash{$statementKey}{'totalExecTime'}+=$totalExecTime;
   $queryHash{$statementKey}{'rowsWritten'}+=$rowsWritten;

   undef $statement;
}

# calculate secPerExec and rowsPerExec for each statement
foreach $statement (keys %queryHash) {
   $numExec=$queryHash{$statement}{'numExec'};
   if($numExec > 0 ) {
      $queryHash{$statement}{'secPerExec'}=$queryHash{$statement}{'totalExecTime'}/$numExec;
      $queryHash{$statement}{'rowsPerExec'}=$queryHash{$statement}{'rowsWritten'}/$numExec;
   }
}

# print newline before we start outputting
print $outputFileHandle "\n";

# do our sorting
if($sortColumn ne "statement") {
   @sortedList = sort { $queryHash{$a}{$sortColumn} <=> $queryHash{$b}{$sortColumn} } keys %queryHash;
} else {
   @sortedList = sort { $queryHash{$a}{$sortColumn} cmp $queryHash{$b}{$sortColumn} } keys %queryHash;
}

print $outputFileHandle "Total number of statements processed: $searchCount (" . (scalar keys %queryHash) . " unique)\n";
print $outputFileHandle "Legend\n";
print $outputFileHandle "   secPerExec - seconds per execution\n";
print $outputFileHandle "   numExec - number of executions\n";
print $outputFileHandle "   rowsW - number of rows written per execution\n";
print $outputFileHandle "   statement - statement executed\n";
print $outputFileHandle "\n";
print $outputFileHandle "Skipping statements that executed in less than $timeCutoff second...\n";
print $outputFileHandle "Truncating output to $statementTruncateLength characters...\n" if($statementTruncateLength>0);

if($includeRowsWritten) {
   print $outputFileHandle "secPerExec   numExec   rowsW    statement\n";
} else {
   print $outputFileHandle "secPerExec   numExec  statement\n";
}

foreach $statement (@sortedList) {
   $numExec=$queryHash{$statement}{'numExec'};
   $secPerExec=$queryHash{$statement}{'secPerExec'};
   $rowsPerExec=$queryHash{$statement}{'rowsPerExec'};

   next if($queryHash{$statement}{'secPerExec'}<=$timeCutoff);

   $displayStatement=$statement;
   $displayStatement=~s/^.*--// if($filterMethod eq "all");

   if($statementTruncateLength>0) {
      $displayStatement=substr($displayStatement,0,$statementTruncateLength) 
   }

   if($includeRowsWritten) {
      printf $outputFileHandle "%10.4f  %8d  %8d  %s\n", $secPerExec, $numExec, $rowsPerExec, $displayStatement;
   } else {
      printf $outputFileHandle "%10.4f  %8d  %s\n", $secPerExec, $numExec, $displayStatement;
   }
}
