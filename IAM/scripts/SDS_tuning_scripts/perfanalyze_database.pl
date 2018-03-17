#!/usr/bin/perl

# perfanalyze_bufferpools.pl | perfanalyze_database.pl
# Author: Casey Peel (cpeel@us.ibm.com)
# Last Updated: 2005/10/10 1527 CDT
# Description:
#    Analyzes database or bufferpool snapshots to report important information
# Usage:
#    This output takes a database or bufferpool snapshot as input.
#    You can get a database snapshot by running:
#       db2 get snapshot for database on DBNAME
#    or
#       db2 get snapshot for bufferpools on DBNAME
#    Alternatively (and perhaps better in general) is to turn
#    monitoring on at the database manager level:
#       db2 update database manager configuration using DFT_MON_BUFPOOL ON
#       db2 update database manager configuration using DFT_MON_LOCK ON
#       db2 update database manager configuration using DFT_MON_SORT ON
#       db2 update database manager configuration using DFT_MON_TABLE ON
#       db2 update database manager configuration using DFT_MON_TIMESTAMP ON
#       db2 update database manager configuration using DFT_MON_UOW ON
#    Then restart your database:
#       db2stop
#       db2start


use Getopt::Std;
use POSIX;

getopts('i:d:o:hs');


# Print Usage and exit
if($opt_h) {
   print <<EOF

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
if($opt_d && $0=~/database/) {
   $date=strftime("%Y%m%d-%H%M",localtime);
   $tempFilename="snapshot-database.$date";
   system("db2 get snapshot for database on $opt_d > $tempFilename");
   open INPUT, $tempFilename || die("Unable to get database snapshot from database, check directory permissions\n");
   $fileHandle=*INPUT;
} elsif($opt_d && $0=~/bufferpool/) {
   $date=strftime("%Y%m%d-%H%M",localtime);
   $tempFilename="snapshot-bufferpool.$date";
   system("db2 get snapshot for bufferpools on $opt_d > $tempFilename");
   open INPUT, $tempFilename || die("Unable to get bufferpool snapshot from database, check directory permissions\n");
   $fileHandle=*INPUT;
}


$outputFileHandle=*STDOUT;
# Open the file to put the output in, if necessary
if($opt_o) {
   open OUTPUT, ">$opt_o" || die("Unable to open $opt_o for writing\n");
   $outputFileHandle=*OUTPUT;
}

# Assume we have a bufferpool snapshot unless we find otherwise
$haveDatabaseSnapshot=0;

$inWantedSection=0;
while($line=<$fileHandle>) {
   chomp($line);
   
   # We support both bufferpool and database snapshots.
   if($line=~/Database Snapshot/) {
      $bpName="ALL";
      $haveDatabaseSnapshot=1;
   }
   
   # In theory, we could be working with a file that has
   # different kinds of snapshots in it, skip lines until
   # we get to the ones we're interested in
   if($line=~/Database Snapshot/ || $line=~/Bufferpool Snapshot/) {
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
   
   # Get the bufferpool name if available
   if($line=~/Bufferpool name\s+=\s+(.*)/i) {
      $bpName=$1;
   }


   # Bufferpools
   if($line=~/Buffer pool data logical reads\s+=\s+(.*)/i) {
      $bps{$bpName}{'bpDataLogicalReads'}=$1;
   } elsif($line=~/Buffer pool data physical reads\s+=\s+(.*)/i) {
      $bps{$bpName}{'bpDataPhysicalReads'}=$1;
   } elsif($line=~/Buffer pool index logical reads\s+=\s+(.*)/i) {
      $bps{$bpName}{'bpIndexLogicalReads'}=$1;
   } elsif($line=~/Buffer pool index physical reads\s+=\s+(.*)/i) {
      $bps{$bpName}{'bpIndexPhysicalReads'}=$1;
   } elsif($line=~/Database files closed\s+=\s+(.*)/i) {
      $bps{$bpName}{'bpDBFilesClosed'}=$1;
   }


   # Connection Information
   if($line=~/High water mark for connections\s+=\s+(.*)/i) {
      $connsHighWaterMark=$1;
   } elsif($line=~/Application connects\s+=\s+(.*)/i) {
      $connsTotal=$1;
   } elsif($line=~/Applications connected currently\s+=\s+(.*)/i) {
      $connsCurrent=$1;
   }


   # Transaction Information
   if($line=~/Commit statements attempted\s+=\s+(.*)/i) {
      $transCommits=$1;
   } elsif($line=~/Rollback statements attempted\s+=\s+(.*)/i) {
      $transRollbacks=$1;
   }


   # Sorts
   if($line=~/Total sorts\s+=\s+(.*)/i) {
      $sortTotal=$1;
   } elsif($line=~/Total sort time \(ms\)\s+=\s+(.*)/i) {
      $sortTotalTime=$1;
   } elsif($line=~/Sort overflows\s+=\s+(.*)/i) {
      $sortOverflows=$1;
   }


   # Locks
   if($line=~/Locks held currently\s+=\s+(.*)/i) {
      $lockCurrent=$1;
   } elsif($line=~/Time database waited on locks \(ms\)\s+=\s+(.*)/i) {
      $lockTimeWait=$1;
   } elsif($line=~/Lock waits\s+=\s+(.*)/i) {
      $lockWaits=$1;
   } elsif($line=~/Deadlocks detected\s+=\s+(.*)/i) {
      $lockDeadlocks=$1;
   } elsif($line=~/Lock escalations\s+=\s+(.*)/i) {
      $lockEscalations=$1;
   }

   # Package cache
   if($line=~/Package cache lookups\s+=\s+(.*)/i) {
      $packageCacheLookups=$1;
   } elsif($line=~/Package cache inserts\s+=\s+(.*)/i) {
      $packageCacheInserts=$1;
   } elsif($line=~/Package cache overflows\s+=\s+(.*)/i) {
      $packageCacheOverflows=$1;
   } elsif($line=~/Package cache high water mark \(Bytes\)\s+=\s+(.*)/i) {
      $packageCacheHighWaterMark=$1;
   }

}

# Bufferpool Calculations
#------------------------------------------------------------------
print $outputFileHandle "Bufferpools:\n";

foreach $bpName (sort keys %bps) {
   print $outputFileHandle "  Bufferpool: $bpName\n";

   if($bps{$bpName}{'bpDataLogicalReads'} eq "Not Collected") {
      print $outputFileHandle "   Statistics not collected\n";
      next;
   }

   $bps{$bpName}{'bpTotalPhysicalReads'}=$bps{$bpName}{'bpDataPhysicalReads'} + $bps{$bpName}{'bpIndexPhysicalReads'};
   $bps{$bpName}{'bpTotalLogicalReads'}=$bps{$bpName}{'bpDataLogicalReads'} + $bps{$bpName}{'bpIndexLogicalReads'};

   # Calculate Hit ratios
   $bpDataHitRatio=(1 - ($bps{$bpName}{'bpDataPhysicalReads'} / $bps{$bpName}{'bpDataLogicalReads'})) * 100;
   $bpIndexHitRatio=(1 - ($bps{$bpName}{'bpIndexPhysicalReads'} / $bps{$bpName}{'bpIndexLogicalReads'})) * 100;
   $bpTotalHitRatio=(1 - ($bps{$bpName}{'bpTotalPhysicalReads'} / $bps{$bpName}{'bpTotalLogicalReads'})) * 100;

   # Print results
   print $outputFileHandle "     Data Hit Ratio: $bpDataHitRatio%\n";
   print $outputFileHandle "    Index Hit Ratio: $bpIndexHitRatio%\n";
   print $outputFileHandle "    Total Hit Ratio: $bpTotalHitRatio%\n";
   print $outputFileHandle "    NOTICE: Total Hit Ratio should be >= 90% (the higher the better)\n" .
      "            Increase the size of the bufferpool until this value approaches 99%.\n"
      if($bpTotalHitRatio<90);

   print $outputFileHandle "\n";
   print $outputFileHandle "    Database files closed: " . $bps{$bpName}{'bpDBFilesClosed'} . "\n";
   print $outputFileHandle "    NOTICE: Database files closed should be = 0\n" .
      "            Increase MAXFILOPs until this counter stops growing.\n" .
      "            see http://www.db2mag.com/db_area/archives/2001/q1/hayes.shtml\n"
      if($bps{$bpName}{'bpDBFilesClosed'}>0);

   print $outputFileHandle "\n";
}


# Check to see if we have a database snapshot, if so continue. Otherwise
# bail out.

goto END if(!$haveDatabaseSnapshot);

# Connections
#------------------------------------------------------------------
print $outputFileHandle "Connections:\n";
print $outputFileHandle "  Total: $connsTotal\n";
print $outputFileHandle "  Current: $connsCurrent\n";
print $outputFileHandle "  High Water Mark: $connsHighWaterMark\n";
print $outputFileHandle "\n";


# Transaction Calculations
#------------------------------------------------------------------
$transTotal=$transCommits+$transRollbacks;

# Print results
print $outputFileHandle "Transactions:\n";
print $outputFileHandle "  Total: $transTotal\n";
print $outputFileHandle "\n";


# Sort Calculations
#------------------------------------------------------------------
$sortSortsPerTrans=$sortTotal/$transTotal;
if($sortTotal==0) {
   $sortOverflowsPerTotalSort=0;
   $sortTimePerSort=0;
} else {
   $sortOverflowsPerTotalSort=$sortOverflows/$sortTotal*100;
   $sortTimePerSort=$sortTotalTime/$sortTotal;
}

# Print results
print $outputFileHandle "Sorts:\n";
print $outputFileHandle "  Total: $sortTotal\n";
print $outputFileHandle "  Average Time per Sort (ms): $sortTimePerSort\n";
print $outputFileHandle "  Average Sorts per Transaction: $sortSortsPerTrans\n";
print $outputFileHandle "  Percentage Overflows: $sortOverflowsPerTotalSort\%\n";

print $outputFileHandle "NOTICE: Percentage Overflows should be <= 3%\n" .
   "Consider increasing SORTHEAP and/or SHEAPTHRES to prevent overflows.\n" .
   "see http://www.db2mag.com/db_area/archives/2001/q1/hayes.shtml\n"
   if($sortOverflowsPerTotalSort>3.0);

print $outputFileHandle "\n";


# Lock Calculations
#------------------------------------------------------------------
if($lockTimeWait==0) {
   $lockTimePerLock=0;
} elsif($lockTimeWait ne "Not Collected") {
   $lockTimePerLock=$lockWaits/$lockTimeWait;
} else {
   $lockTimePerLock="not collected";
}
$lockLockPerTrans=$lockWaits/$transTotal;

# Print results
print $outputFileHandle "Locks:\n";
print $outputFileHandle "  Current: $lockCurrent\n";
print $outputFileHandle "  Total: $lockWaits\n";
print $outputFileHandle "  Average Time per Lock (ms): $lockTimePerLock\n";
print $outputFileHandle "  Average Lock per Transaction: $lockLockPerTrans\n";
print $outputFileHandle "  Deadlocks: $lockDeadlocks\n";
print $outputFileHandle "  Escalations: $lockEscalations\n";

print $outputFileHandle "\n";


# Package cache info
#------------------------------------------------------------------
print $outputFileHandle "Package cache:\n";
print $outputFileHandle "  Lookups: $packageCacheLookups\n";
print $outputFileHandle "  Inserts: $packageCacheInserts\n";
print $outputFileHandle "  Overflows: $packageCacheOverflows\n";

print $outputFileHandle "NOTICE: Package overflows should be zero.\n" .
   "Increase PCKCACHESZ to prevent overflows"
   if($packageCacheOverflows>0);


END:
# Clean up after ourselves
if($opt_d && !$opt_s) {
   unlink $tempFilename if(-f $tempFilename);
}