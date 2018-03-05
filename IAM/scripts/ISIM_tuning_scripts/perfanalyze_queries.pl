#!/usr/bin/perl

# perfanalyze_queries.pl
# Author: Casey Peel (cpeel@us.ibm.com)
# Last Updated: 2005/10/10 1527 CDT
# Description:
#    Analyzes queries
# Usage:
#    This takes either:
#       1) one or more processed dynamic sql snapshots
#          (via perfanalyze_dynamicsql.pl) as input.
#     - or -
#       2) any other text input with one query per line

use Getopt::Std;
use POSIX;

getopts('i:o:r:t:hs');

# Debug?
$DEBUG=0;

# Print Usage and exit
if($opt_h) {
   print <<EOF

Usage: $0 [ -i inputFile ] [ -o outputFile ] [ -r <string> ] [ -t <num> ] 
-i - file containing dynamic sql statements for processing
-o - file to put the processed results in, default is STDOUT
-r - column to sort by, default is secPerExec
-t - length to truncate statement at, default is 80 characters. 0 = don't truncate.

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
   print "reading snapshot from STDIN\n";
   $fileHandle=*STDIN;
}


if($opt_t ne "") {
   $statementTruncateLength=$opt_t;
} else {
   $statementTruncateLength=80;
}


if($opt_r ne "") {
   $sortColumn=$opt_r;
} else {
   $sortColumn='numExec';
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

# Now actually do the parsing
while($line=<$fileHandle>) {
   # make sure the line has a query we're interested in
   next if(!($line=~/select /i || $line=~/update /i || $line=~/delete /i || $line=~/insert /i));
   
   # Pull the query out. If this is a dynamicsql-parsed snapshot retain the numExec (second column)
   if($line=~/^\s+\d+\.\d+\s+(\d+)\s+\d+\s+(.*)$/) {
      $statement=$2;
      $queryHash{$statement}{$statement}=$statement;
      $queryHash{$statement}{'numExec'}+=$1;
   } else {
      $line=~/^\s*(.*)\s*$/;
      $statement=$1;
      # if we have a db2evmon output, remove the leading part of the statement
      $statement=~s/^Text     : //;
      $queryHash{$statement}{$statement}=$statement;
      $queryHash{$statement}{'numExec'}++;
   }
   print STDERR $line if($DEBUG);
}

@sortedList = sort { $queryHash{$a}{$sortColumn} <=> $queryHash{$b}{$sortColumn} } keys %queryHash;

print $outputFileHandle "Legend\n";
print $outputFileHandle "   numExec - number of executions\n";
print $outputFileHandle "   statement - statement executed\n";
print $outputFileHandle "numExec   statement\n";
foreach $statement (@sortedList) {

   if($statementTruncateLength>0) {
      $statementTrunc=substr($statement,0,$statementTruncateLength) 
   } else {
      $statementTrunc=$statement;
   }

   printf $outputFileHandle "%8d  %8s\n", $queryHash{$statement}{'numExec'}, $statementTrunc;
}

