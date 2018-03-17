#!/usr/bin/perl

# perfanalyze_tables.pl
# Author: Casey Peel (cpeel@us.ibm.com)
# Last Updated: 2005/10/10 1527 CDT
# Description:
#    Analyzes tables snapshots for problems 
# Usage:
#    This output takes a table snapshot as input.
#    You can get a tables snapshot by running:
#       db2 get snapshot for tables on DBNAME
#    Alternatively (and perhaps better in general) is to turn
#    monitoring on at the database manager level:
#       db2 update database manager configuration using DFT_MON_TABLE ON
#    Then restart your database:
#       db2stop
#       db2start

use Getopt::Std;
use POSIX;

getopts('i:d:o:c:hs');

# Debug?
$DEBUG=0;

# Print Usage and exit
if($opt_h) {
   print <<EOF

Usage: $0 [ -i inputFile | [ -d databaseName | -s ] ] [ -o outputFile ]
-i - file containing snapshot for processing
-d - database name to get snapshot from database directly
-s - if given the temporary file with the snapshot will be saved
-o - file to put the processed results in, default is STDOUT
-r - column to sort by, default is rowsRead

If no arguments are given, the program will read input from STDIN.

EOF
;
exit;
}

# Default input is STDIN
$fileHandle=*STDIN;

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
if($opt_d) {
   $date=strftime("%Y%m%d-%H%M",localtime);
   $tempFilename="snapshot-tables.$date";
   system("db2 get snapshot for tables on $opt_d > $tempFilename");
   open INPUT, $tempFilename || die("Unable to get table snapshot from database, check directory permissions\n");
   $fileHandle=*INPUT;
}


# Default output file is STDOUT
$outputFileHandle=*STDOUT;

# Open the file to put the output in, if necessary
if($opt_o) {
   open OUTPUT, ">$opt_o" || die("Unable to open $opt_o for writing\n");
   $outputFileHandle=*OUTPUT;
}

if(!$opt_r) {
   $sortColumn="rowsRead";
} else {
   $sortColumn=$opt_r;
}


$inWantedSection=0;

# Now actually do the parsing
while($line=<$fileHandle>) {
   chomp($line);
   
   # In theory, we could be working with a file that has
   # different kinds of snapshots in it, skip lines until
   # we get to the ones we're interested in
   if($line=~/Table Snapshot/) {
      $inWantedSection=1;
      next;
   }
   
   # if we're in any other section, stop processing
   if($line=~/ Snapshot/) {
      $inWantedSection=0;
   }
   
   next if(!$inWantedSection);
   
   # If we're in the section we want, set inWantedSection=1;
   $inWantedSection=1;
   
   print STDERR "$line\n" if($DEBUG);
   if($line=~/Table Name\s+=\s+(\w+)/i) {
      $tableName=$1;
      $tableHash{$tableName}{'tableName'}=$tableName;
   } elsif($line=~/Rows Read\s+=\s+(\w+)/i) {
      $data=$1;
      $data="N/A" if($data=~/not collected/i);
      $tableHash{$tableName}{'rowsRead'}=$data;
   } elsif($line=~/Rows Written\s+=\s+(\w+)/i) {
      $tableHash{$tableName}{'rowsWritten'}=$1;
   } elsif($line=~/Overflows\s+=\s+(\w+)/i) {
      $tableHash{$tableName}{'overflows'}=$1;
   } elsif($line=~/Page Reorgs\s+=\s+(\w+)/i) {
      $tableHash{$tableName}{'pageReorgs'}=$1;
   }

   $sortHash{$tableName}=$tableHash{$tableName}{$sortColumn};
}

@sortedList = sort { $sortHash{$a} <=> $sortHash{$b} } keys %sortHash;

print "tableName                          rowsRead  rowsWritten    overflows   pageReorgs\n";
foreach $tableName (@sortedList) {
   $rowsRead=$tableHash{$tableName}{'rowsRead'};
   $rowsWritten=$tableHash{$tableName}{'rowsWritten'};
   $overflows=$tableHash{$tableName}{'overflows'};
   $pageReorgs=$tableHash{$tableName}{'pageReorgs'};
   printf "%-30s   %10s   %10d   %10d   %10d\n", $tableName, $rowsRead, $rowsWritten, $overflows, $pageReorgs;
}

# Clean up after ourselves
if($opt_d && !$opt_s) {
   unlink $tempFilename if(-f $tempFilename);
}
