#!/usr/bin/perl

# perfanalyze_dynamicsql.pl
# Author: Casey Peel (cpeel@us.ibm.com)
# Last Updated: 2006/01/26 1550 CDT
# Description:
#    Analyzes dynamic sql snapshots for problem queries
# Usage:
#    This output takes a dynamic sql snapshot as input.
#    You can get a dynamic sql snapshot by running:
#       db2 get snapshot for dynamic sql on DBNAME
#    Alternatively (and perhaps better in general) is to turn
#    monitoring on at the database manager level:
#       db2 update database manager configuration using DFT_MON_STMT ON
#    Then restart your database:
#       db2stop
#       db2start
#    You can reset the monitor statistics with the following:
#       db2 reset monitor all

use Getopt::Std;
use POSIX;

getopts('i:d:o:t:c:r:hsnw');

# Debug?
$DEBUG=0;

# Print Usage and exit
if($opt_h) {
   print <<EOF

Usage: $0 [ -i inputFile | [ -d databaseName | -s ] ] [ -o outputFile ]
-i - file containing dynamic sql statements for processing
-d - database name to get dynamic sql statements from directly
-s - if given the temporary file with the dynamic sql will be saved
-o - file to put the processed results in, default is STDOUT
-t - length to truncate statement at, default is 90 characters. 0 = don't truncate.
-c - time cutoff; statements longer than this time are not included, default is 0.1
-r - column to sort by, default is secPerExec
-n - include queries that have no statistics information
-w - include the number of rows written

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


# Fetch the data from the database ourselves
if($opt_d ne "") {
   print "getting snapshot from database $opt_d\n";
   $date=strftime("%Y%m%d-%H%M",localtime);
   $tempFilename="snapshot-dynamicsql.$date";
   system("db2 get snapshot for dynamic sql on $opt_d > $tempFilename");
   open INPUT, $tempFilename || die("Unable to get dynamic sql from database, check directory permissions\n");
   $fileHandle=*INPUT;
}

# Default input is STDIN
if(!$fileHandle) {
   print STDERR "reading snapshot from STDIN\n";
   $fileHandle=*STDIN;
}

# set defaults
$timeCutoff=0.1;
$statementTruncateLength=80;
$sortColumn='secPerExec';
$includeNAStats=0;
$includeRowsWritten=0;

# get the command-line options if specified
$statementTruncateLength=$opt_t if($opt_t ne "");
$timeCutoff=$opt_c if($opt_c ne "");
$sortColumn=$opt_r if($opt_r ne "");
$includeNAStats=1 if($opt_n ne "");
$includeRowsWritten=1 if($opt_w ne "");


# Default output file is STDOUT
$outputFileHandle=*STDOUT;

# Unbuffer $outputFileHandle
select((select($outputFileHandle), $|=1)[0]);

# Open the file to put the output in, if necessary
if($opt_o) {
   open OUTPUT, ">$opt_o" || die("Unable to open $opt_o for writing\n");
   $outputFileHandle=*OUTPUT;
}

# print status indicator
print STDERR "processing snapshot";

# Now actually do the parsing
while($line=<$fileHandle>) {
   print STDERR $line if($DEBUG);
   
   if($line=~/^ Number of executions/ && $statement) {
      print STDERR ".";
      $queryHash{$statement}{'statement'}=$statement;
      $queryHash{$statement}{'numExec'}=$numExecutions;
      $queryHash{$statement}{'totalExecTime'}=$totalExecTime;
      $queryHash{$statement}{'rowsWritten'}=$rowsWritten;

      if($numExecutions>0 && $totalExecutionTime ne "N/A") {
         $secPerExec=$totalExecutionTime/$numExecutions;
         $rowsPerExec=$rowsWritten/$numExecutions;

         $queryHash{$statement}{'secPerExec'}=$secPerExec;
         $queryHash{$statement}{'rowsPerExec'}=$rowsPerExec;
      } else {
         $queryHash{$statement}{'secPerExec'}="N/A";
         $queryHash{$statement}{'rowsPerExec'}="N/A";
      }
      undef $statement;
   }

   if($line=~/^ Database name\s+= (.*)$/i) {
      $databaseName=$1;
   } elsif($line=~/^ Number of executions\s+= (.*)$/i) {
      $data=$1; $data="N/A" if($data=~/not collected/i);
      $numExecutions=$data;
   } elsif($line=~/^ Total execution time.*= (.*)$/i) {
#   } elsif($line=~/^ Total user cpu time.*= (.*)$/i) {
      $data=$1; $data="N/A" if($data=~/not collected/i);
      $totalExecutionTime=$data;
   } elsif($line=~/^ Rows written\s+= (.*)$/i) {
      $data=$1; $data="N/A" if($data=~/not collected/i);
      $rowsWritten=$data;
   } elsif($line=~/^ Statement text\s+= (.*)$/i) {
      $statement=$1;
      # a little statement normalization
      $statement=~s#^(.*?)\s+(\s.*')#$1$2#g;
      $statement=~s#('.*\s)\s+(.*?)$#$1$2#g;
   }
}

# before actually printing anything, see if our file was valid
if($databaseName eq "") {
   die("Input was not a valid db2 dynamic sql snapshot, no analysis done.\n");
}

# print newline before we start outputting
print "\n";

#@sortedBySecPerExec = sort { $statementSecPerExec{$a} <=> $statementSecPerExec{$b} } keys %statementSecPerExec;
if($sortColumn ne "statement") {
   @sortedList = sort { $queryHash{$a}{$sortColumn} <=> $queryHash{$b}{$sortColumn} } keys %queryHash;
} else {
   @sortedList = sort { $queryHash{$a}{$sortColumn} cmp $queryHash{$b}{$sortColumn} } keys %queryHash;
}


print $outputFileHandle "Dynamic SQL analysis for database: $databaseName\n";
print $outputFileHandle "Total number of statements processed: " . (scalar keys %queryHash) . "\n";
print $outputFileHandle "Legend\n";
print $outputFileHandle "   secPerExec - seconds per execution\n";
print $outputFileHandle "   numExec - number of executions\n";
print $outputFileHandle "   rowsW - number of rows written per execution\n";
print $outputFileHandle "   statement - statement executed\n";
print $outputFileHandle "Skipping statements that executed in less than $timeCutoff second...\n";

if($includeRowsWritten) {
   print $outputFileHandle "secPerExec   numExec   rowsW    statement\n";
} else {
   print $outputFileHandle "secPerExec   numExec  statement\n";
}

foreach $statement (@sortedList) {
   $numExec=$queryHash{$statement}{'numExec'};
   $secPerExec=$queryHash{$statement}{'secPerExec'};
   $rowsPerExec=$queryHash{$statement}{'rowsPerExec'};

   next if($queryHash{$statement}{'secPerExec'} eq "N/A" && !$includeNAStats);
   next if($queryHash{$statement}{'secPerExec'}<=$timeCutoff && $queryHash{$statement}{'secPerExec'} ne "N/A");

   if($statementTruncateLength>0) {
      $statementTrunc=substr($statement,0,$statementTruncateLength) 
   } else {
      $statementTrunc=$statement;
   }

   if($includeRowsWritten) {
      if($secPerExec eq "N/A") {
         printf $outputFileHandle "%10s  %8d  %8s  %s\n", $secPerExec, $numExec, $rowsPerExec, $statementTrunc;
      } else {
         printf $outputFileHandle "%10.4f  %8d  %8d  %s\n", $secPerExec, $numExec, $rowsPerExec, $statementTrunc;
      }
   } else {
      if($secPerExec eq "N/A") {
         printf $outputFileHandle "%10s  %8d  %s\n", $secPerExec, $numExec, $statementTrunc;
      } else {
         printf $outputFileHandle "%10.4f  %8d  %s\n", $secPerExec, $numExec, $statementTrunc;
      }
   }
}


# Clean up after ourselves
if($opt_d && !$opt_s) {
   unlink $tempFilename if(-f $tempFilename);
}
