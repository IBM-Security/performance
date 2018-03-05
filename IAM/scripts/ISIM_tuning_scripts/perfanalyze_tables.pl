#!/usr/bin/perl

# perfanalyze_tables.pl
# Author: Casey Peel (cpeel@us.ibm.com)
# Last Updated: 2008/05/14 1644 MDT
# Summary:
#    Analyzes tables snapshots for problems such as table scans.
# Description:
#    This script reads in a table snapshot and gives a grid-like output
#    on rows read/written for each table.
#
#    This output takes a table snapshot as input. Table monitoring must
#    be enabled prior to the snapshot for this report to generate useful
#    results.
#
#    You can get a dynamic sql snapshot by running:
#       db2 connect to DBNAME
#       db2 get snapshot for tables on DBNAME
#    or
#       db2 connect to DBNAME
#       db2 get snapshot for all on DBNAME
#    as the ITDS database owner.
#
#    Note: having DB2 table monitoring on can be a performance hit, you may
#    not want to have it enabled all the time.


use Getopt::Std;
use POSIX;

# Debug?
$Debug=0;

getopts('i:d:o:c:r:hs') or usage();
usage() if($opt_h);

# Print Usage and exit
sub usage {
   print STDERR <<EOF

Usage: $0 [ -i inputFile | [ -d databaseName | -s ] ] [ -o outputFile ] [ -c cutOff | -r sortColumn ]
Output options:
  -r - column to sort by, default is rowsRead
  -c - tables where number(sortColumn) < cutOff are not included, default is 100

Other options:
  -i - file containing snapshot for processing
  -d - database name to get snapshot from database directly
  -s - if given the temporary file with the snapshot will be saved
  -o - file to put the processed results in, default is STDOUT

If no arguments are given, the program will read input from STDIN.

EOF
;
exit;
}

# Only specify either -i or -d
if($opt_i && $opt_d) {
   print STDERR "Only one of the -i or the -d parameters should be used at a time.\n";
   print STDERR "If you have a snapshot already, use -i.\n";
   print STDERR "If you want to have the script pull the snapshot, use -d.\n";
   exit 1;
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
if($opt_d) {
   $date=strftime("%Y%m%d-%H%M",localtime);
   $tempFilename="snapshot-tables.$date";
   system("db2 get snapshot for tables on $opt_d > $tempFilename");
   open INPUT, $tempFilename || die("Unable to get table snapshot from database, check directory permissions\n");
   $fileHandle=*INPUT;
}

# Default input is STDIN
if(!$fileHandle) {
   print STDERR "no input file specified (-i), reading input from STDIN\n";
   print STDERR "Hint: use the -h option to get the usage statement\n";
   $fileHandle=*STDIN;
}

# Default output file is STDOUT
$outputFileHandle=*STDOUT;

# Open the file to put the output in, if necessary
if($opt_o) {
   open OUTPUT, ">$opt_o" || die("Unable to open $opt_o for writing\n");
   $outputFileHandle=*OUTPUT;
}

# Unbuffer $outputFileHandle
select((select($outputFileHandle), $|=1)[0]);

# set up default values
$sortColumn="rowsRead";
$tableCutoff=100;

$sortColumn=$opt_r if($opt_r);
$tableCutoff=$opt_c if($opt_c ne "");


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

print $outputFileHandle "skipping tables with $sortColumn < $tableCutoff\n" if($tableCutoff);
print $outputFileHandle "tableName                          rowsRead  rowsWritten    overflows   pageReorgs\n";
foreach $tableName (@sortedList) {
   next if($tableHash{$tableName}{$sortColumn} < $tableCutoff);

   $rowsRead=$tableHash{$tableName}{'rowsRead'};
   $rowsWritten=$tableHash{$tableName}{'rowsWritten'};
   $overflows=$tableHash{$tableName}{'overflows'};
   $pageReorgs=$tableHash{$tableName}{'pageReorgs'};

   printf $outputFileHandle "%-30s   %10s   %10d   %10d   %10d\n", $tableName, $rowsRead, $rowsWritten, $overflows, $pageReorgs;
}

# Clean up after ourselves
if($opt_d && !$opt_s) {
   unlink $tempFilename if(-f $tempFilename);
}
