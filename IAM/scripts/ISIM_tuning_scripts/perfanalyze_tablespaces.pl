#!/usr/bin/perl

# perfanalyze_tablespaces.pl
# Author: Casey Peel (cpeel@us.ibm.com)
# Last Updated: 2008/05/14 1644 MDT
# Summary:
#    Analyzes tablespaces snapshots to report important information
# Description:
#    This script takes a DB2 tablespaces snapshot and gives recommendations
#    on parameters to tune based on calculations made from the snapshot.
#
#    This script makes use of the data from sort, lock, and bufferpool
#    monitoring from DB2. These three monitoring flags must be enabled
#    prior to the snapshot for this report to generate useful results.
#
#    You can get a dynamic sql snapshot by running:
#       db2 connect to DBNAME
#       db2 get snapshot for database on DBNAME
#       db2 get snapshot for bufferpools on DBNAME
#    or
#       db2 connect to DBNAME
#       db2 get snapshot for all on DBNAME
#    as the ITDS database owner.
#

use Getopt::Std;
use POSIX;

# Debug?
$Debug=0;

getopts('i:d:o:hs') or usage();
usage() if($opt_h);

# Print Usage and exit
sub usage {
   print STDERR <<EOF

Usage: $0 [ -i inputFile | [ -d databaseName | -s ] ] [ -o outputFile ]
  -i - file containing snapshot for processing
  -d - database name to get snapshot from directly
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

# Default input is STDIN
if(!$fileHandle) {
   print STDERR "no input file specified (-i), reading input from STDIN\n";
   print STDERR "Hint: use the -h option to get the usage statement\n";
   $fileHandle=*STDIN;
}

# Fetch the data from the database ourselves
if($opt_d) {
   $date=strftime("%Y%m%d-%H%M",localtime);
   $tempFilename="snapshot-tablespace.$date";
   system("db2 get snapshot for tablespaces on $opt_d > $tempFilename");
   open INPUT, $tempFilename || die("Unable to get tablespace snapshot from database, check directory permissions\n");
   $fileHandle=*INPUT;
}


$outFH=*STDOUT;
# Open the file to put the output in, if necessary
if($opt_o) {
   open OUTPUT, ">$opt_o" || die("Unable to open $opt_o for writing\n");
   $outFH=*OUTPUT;
}

$inWantedSection=0;
while($line=<$fileHandle>) {
   $line=~s/[\r\n]+//g;
   
   # In theory, we could be working with a file that has
   # different kinds of snapshots in it, skip lines until
   # we get to the ones we're interested in
   if($line=~/Tablespace Snapshot/) {
      $inWantedSection=1;
      next;
   }
   
   # if we're in any other section, stop processing
   if($line=~/ Snapshot/) {
      $inWantedSection=0;
   }
   
   next if(!$inWantedSection);
   
   # Get data from file
   if($line=~/Tablespace name\s+=\s+(.*)/i) {
      $tsName=$1;
   } elsif($line=~/Tablespace ID\s+=\s+(.*)/i) {
      $tss{$tsName}{'tsID'}=$1;
   } elsif($line=~/Tablespace Type\s+=\s+(.*)/i) {
      $tss{$tsName}{'tsType'}=$1;
   } elsif($line=~/Auto-resize enabled\s+=\s+(.*)/i) {
      $tss{$tsName}{'tsAutoresize'}=$1;
   } elsif($line=~/File system caching\s+=\s+(.*)/i) {
      $tss{$tsName}{'tsFileSystemCaching'}=$1;
   } elsif($line=~/Tablespace Extent size \(pages\)\s+=\s+(.*)/i) {
      $tss{$tsName}{'tsExtentSizePages'}=$1;
   } elsif($line=~/Tablespace Prefetch Size \(pages\)\s+=\s+(.*)/i) {
      $tss{$tsName}{'tsPrefetchSizePages'}=$1;
   } elsif($line=~/Total number of pages\s+=\s+(.*)/i) {
      $tss{$tsName}{'tsTotalPages'}=$1;
   } elsif($line=~/Number of free pages\s+=\s+(.*)/i) {
      $tss{$tsName}{'tsFreePages'}=$1;
   }
}

# Tablespaces
#------------------------------------------------------------------
foreach $tsName (sort keys %tss) {
   # Calculate values
   $tsPercentFreePages='N/A';
   $tsPercentFreePages=$tss{$tsName}{'tsFreePages'} / $tss{$tsName}{'tsTotalPages'} * 100
      if($tss{$tsName}{'tsTotalPages'});
   $tsMultipleOfPrefetchExtents='N/A';
   $tsMultipleOfPrefetchExtents=$tss{$tsName}{'tsPrefetchSizePages'} / $tss{$tsName}{'tsExtentSizePages'}
      if($tss{$tsName}{'tsExtentSizePages'});

   print $outFH "Tablespace: $tsName (id: " . $tss{$tsName}{'tsID'} . ")\n";

#   if($tss{$tsName}{'bpDataLogicalReads'} eq "Not Collected") {
#      print $outFH "   Statistics not collected\n";
#      next;
#   }

   # Print results
   print $outFH "\n";
   print $outFH "        Tablespace Type: " . $tss{$tsName}{'tsType'} . "\n";
   print $outFH "    Auto-resize enabled: " . $tss{$tsName}{'tsAutoresize'} . "\n"
      if($tss{$tsName}{'tsType'} eq "Database managed space");
   print $outFH "       NOTICE: You may want to enable auto-resize for this tablespace\n" .
                "               to reduce administrative overhead although care should be\n" .
                "               taken to ensure the file system doesn't run out of disk space.\n"
      if($tss{$tsName}{'tsType'} eq "Database managed space" && $tss{$tsName}{'tsAutoresize'} eq "No");
   print $outFH "    File system caching: " . $tss{$tsName}{'tsFileSystemCaching'} . "\n";
   print $outFH "       NOTICE: You may want to disable file system caching for this tablespace\n" .
                "               if your bufferpool hit ratio is very high to take advantage of\n" .
                "               Direct I/O (DIO) or Concurrent I/O (CIO) on supported platforms.\n"
      if($tss{$tsName}{'tsFileSystemCaching'} eq "Yes");

   if($tss{$tsName}{'tsType'} eq "Database managed space") {
      print $outFH "\n";
      print $outFH sprintf("     Total pages: %d\n", $tss{$tsName}{'tsTotalPages'});
      print $outFH sprintf("      Free pages: %d (%0.3f%%)\n", $tss{$tsName}{'tsFreePages'}, $tsPercentFreePages);
   }

   print $outFH "\n";
   print $outFH sprintf("     Extent size (pages): %d\n", $tss{$tsName}{'tsExtentSizePages'});
   print $outFH sprintf("   Prefetch size (pages): %d (%d extents)\n", $tss{$tsName}{'tsPrefetchSizePages'},$tsMultipleOfPrefetchExtents);
   print $outFH "     NOTICE: Prefetch size should be a multiple of extent size.\n"
      if($tss{$tsName}{'tsPrefetchSizePages'} % $tss{$tsName}{'tsExtentSizePages'});

   print $outFH "\n";
}


# Clean up after ourselves
if($opt_d && !$opt_s) {
   unlink $tempFilename if(-f $tempFilename);
}
