#!/usr/bin/perl

# perfanalyze_bufferpools.pl | perfanalyze_database.pl
# Author: Casey Peel (cpeel@us.ibm.com)
# Last Updated: 2008/07/23 1418 MDT
# Summary:
#    Analyzes database or bufferpool snapshots to report important information
# Description:
#    This script takes a DB2 database or bufferpool snapshot and gives
#    recommendations on parameters to tune based on calculations made from the
#    snapshot.
#
#    This script makes use of the data from sort, lock, and bufferpool
#    monitoring from DB2. These three monitoring flags must be enabled
#    prior to the snapshot for this report to generate useful results.
#
#    You can get database and bufferpool snapshots by running:
#       db2 connect to DBNAME
#       db2 get snapshot for database on DBNAME
#       db2 get snapshot for bufferpools on DBNAME
#    or get a composite snapshot by running:
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
   $tempFilename="snapshot-composite.$date";
   system("db2 get snapshot for all on $opt_d > $tempFilename");
   open INPUT, $tempFilename || die("Unable to get composite snapshot from database, check directory permissions\n");
   $fileHandle=*INPUT;
}


$outFH=*STDOUT;
# Open the file to put the output in, if necessary
if($opt_o) {
   open OUTPUT, ">$opt_o" || die("Unable to open $opt_o for writing\n");
   $outFH=*OUTPUT;
}

# Assume we have a bufferpool snapshot unless we find otherwise
$haveDatabaseSnapshot=0;

$inWantedSection=0;
while($line=<$fileHandle>) {
   $line=~s/[\r\n]+//g;
   
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
   } elsif($line=~/Buffer pool data writes\s+=\s+(.*)/i) {
      $bps{$bpName}{'bpDataWrites'}=$1;
   } elsif($line=~/Asynchronous pool data page writes\s+=\s+(.*)/i) {
      $bps{$bpName}{'bpDataAsynchDataWrites'}=$1;
   } elsif($line=~/Buffer pool index writes\s+=\s+(.*)/i) {
      $bps{$bpName}{'bpIndexWrites'}=$1;
   } elsif($line=~/Asynchronous pool index page writes\s+=\s+(.*)/i) {
      $bps{$bpName}{'bpDataAsynchIndexWrites'}=$1;
   } elsif($line=~/Direct reads\s+=\s+(.*)/i) {
      $bps{$bpName}{'bpDataDirectReads'}=$1;
   } elsif($line=~/Direct writes\s+=\s+(.*)/i) {
      $bps{$bpName}{'bpDataDirectWrites'}=$1;
   } elsif($line=~/No victim buffers available\s+=\s+(.*)/i) {
      $bps{$bpName}{'bpDataNoVictimsAvail'}=$1;
   } elsif($line=~/Current size\s+=\s+(.*)/i) {
      $bps{$bpName}{'bpCurrentSize'}=$1;
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
print $outFH "Bufferpools:\n";

foreach $bpName (sort keys %bps) {
   $bps{$bpName}{'bpTotalPhysicalReads'}=$bps{$bpName}{'bpDataPhysicalReads'} + $bps{$bpName}{'bpIndexPhysicalReads'};
   $bps{$bpName}{'bpTotalLogicalReads'}=$bps{$bpName}{'bpDataLogicalReads'} + $bps{$bpName}{'bpIndexLogicalReads'};

   # Confirm that monitoring is enabled
   die("\nDB2 monitoring wasn't enabled when the snapshot was pulled. Nothing to do here.\n")
      if($bps{$bpName}{'bpDataLogicalReads'} eq "Not Collected");

   # Calculate Hit ratios
   $bpDataHitRatio=$bpIndexHitRatio=$bpTotalHitRatio=0;
   $bpDataHitRatio=(1 - ($bps{$bpName}{'bpDataPhysicalReads'} / $bps{$bpName}{'bpDataLogicalReads'})) * 100
      if($bps{$bpName}{'bpDataLogicalReads'});
   $bpIndexHitRatio=(1 - ($bps{$bpName}{'bpIndexPhysicalReads'} / $bps{$bpName}{'bpIndexLogicalReads'})) * 100
      if($bps{$bpName}{'bpIndexLogicalReads'});
   $bpTotalHitRatio=(1 - ($bps{$bpName}{'bpTotalPhysicalReads'} / $bps{$bpName}{'bpTotalLogicalReads'})) * 100
      if($bps{$bpName}{'bpTotalLogicalReads'});

   # Calculate sync writes
   $bpDataSyncRatio=$bpIndexSyncRatio=$bpTotalSyncRatio=0;
   $bpDataWrites=$bps{$bpName}{'bpDataWrites'};
   $bpDataSyncs=$bpDataWrites - $bps{$bpName}{'bpDataAsynchDataWrites'};
   $bpDataSyncRatio=($bpDataSyncs / $bpDataWrites) * 100
      if($bpDataWrites);
   $bpIndexWrites=$bps{$bpName}{'bpIndexWrites'};
   $bpIndexSyncs=$bpIndexWrites - $bps{$bpName}{'bpDataAsynchIndexWrites'};
   $bpIndexSyncRatio=($bpIndexSyncs / $bpIndexWrites) * 100
      if($bpIndexWrites);
   $bpTotalSyncs=($bpIndexWrites + $bpDataWrites) - ($bps{$bpName}{'bpDataAsynchIndexWrites'} + $bps{$bpName}{'bpDataAsynchDataWrites'});
   $bpTotalSyncRatio=($bpTotalSyncs / ($bpIndexWrites + $bpDataWrites)) * 100
      if($bpIndexWrites + $bpDataWrites);

   # if bpTotalHitRatio is zero, this bufferpool isn't used so skip it
   next if($bpTotalHitRatio==0);

   print $outFH "  Bufferpool: $bpName\n";

   if($bps{$bpName}{'bpDataLogicalReads'} eq "Not Collected") {
      print $outFH "   Statistics not collected\n";
      next;
   }

   # Print results
   print $outFH "    Current size: " . $bps{$bpName}{'bpCurrentSize'} . " pages\n"
      if($bps{$bpName}{'bpCurrentSize'});

   print $outFH sprintf("    Hit ratios (the higher the better)\n");
   print $outFH sprintf("      Data:  %7.3f%%\n", $bpDataHitRatio);
   print $outFH sprintf("      Index: %7.3f%%\n", $bpIndexHitRatio);
   print $outFH sprintf("      Total: %7.3f%%\n",  $bpTotalHitRatio);
   print $outFH "    NOTICE: Total Hit Ratio should be >= 90% (the higher the better)\n" .
                "            Increase the size of the bufferpool until this value approaches 99%.\n"
      if($bpTotalHitRatio<90 && $bpTotalHitRatio>0);
   print $outFH "    NOTICE: Total Hit Ratio is < 0 because there are more physical reads\n" .
                "            than logical reads. This is either because the system has just\n" .
                "            started or the bufferpools are unresonably small.\n"
      if($bpTotalHitRatio<0);

   print $outFH sprintf("    Sync write ratios (the lower the better)\n");
   print $outFH sprintf("      Data:  %7.3f%% (%6d syncs, %6d asyncs)\n",
      $bpDataSyncRatio, $bpDataSyncs, $bps{$bpName}{'bpDataAsynchDataWrites'});
   print $outFH sprintf("      Index: %7.3f%% (%6d syncs, %6d asyncs)\n",
      $bpIndexSyncRatio, $bpIndexSyncs, $bps{$bpName}{'bpDataAsynchIndexWrites'});
   print $outFH sprintf("      Total: %7.3f%% (%6d syncs, %6d asyncs)\n",
      $bpTotalSyncRatio, $bpTotalSyncs, ($bps{$bpName}{'bpDataAsynchIndexWrites'}+$bps{$bpName}{'bpDataAsynchDataWrites'})); 
   print $outFH "    NOTICE: You may need to increase NUM_IOCLEANERS to decrease\n" .
                "            the number of sync writes.\n"
      if($bpTotalSyncRatio > 30);

   print $outFH "    Direct reads:  " . $bps{$bpName}{"bpDataDirectReads"} . "\n";
   print $outFH "    Direct writes: " . $bps{$bpName}{"bpDataDirectWrites"} . "\n";

   print $outFH "    Database files closed: " . $bps{$bpName}{'bpDBFilesClosed'} . "\n";
   print $outFH "    NOTICE: Database files closed should be = 0\n" .
                "            Increase MAXFILOPs until this counter stops growing.\n" .
                "            see http://www.db2mag.com/db_area/archives/2001/q1/hayes.shtml\n"
      if($bps{$bpName}{'bpDBFilesClosed'}>0);

   print $outFH "\n";
}


# Check to see if we have a database snapshot, if so continue. Otherwise
# bail out.

goto END if(!$haveDatabaseSnapshot);

# Connections
#------------------------------------------------------------------
print $outFH "Connections:\n";
print $outFH "  Total: $connsTotal\n";
print $outFH "  Current: $connsCurrent\n";
print $outFH "  High Water Mark: $connsHighWaterMark\n";
print $outFH "\n";


# Transaction Calculations
#------------------------------------------------------------------
$transTotal=$transCommits+$transRollbacks;

# Print results
print $outFH "Transactions:\n";
print $outFH "  Total: $transTotal\n";
print $outFH "  NOTICE: 0 transactions likely means this database was just started\n".
             "          and the data provided by this script is worthless until\n".
             "          the system has been used and real metrics gathered.\n"
   if($transTotal==0);
print $outFH "\n";


# Sort Calculations
#------------------------------------------------------------------
$sortSortsPerTrans=0;
$sortSortsPerTrans=$sortTotal/$transTotal
   if($transTotal);
if($sortTotal==0) {
   $sortOverflowsPerTotalSort=0;
   $sortTimePerSort=0;
} else {
   $sortOverflowsPerTotalSort=$sortOverflows/$sortTotal*100;
   $sortTimePerSort=$sortTotalTime/$sortTotal;
}

# Print results
print $outFH "Sorts:\n";
print $outFH "  Total: $sortTotal\n";
print $outFH "  Average Time per Sort (ms): $sortTimePerSort\n";
print $outFH "  Average Sorts per Transaction: $sortSortsPerTrans\n";
print $outFH "  Percentage Overflows: $sortOverflowsPerTotalSort\%\n";

print $outFH "NOTICE: Percentage Overflows should be <= 3%\n" .
             "        Consider increasing SORTHEAP and/or SHEAPTHRES to prevent overflows.\n" .
             "        see http://www.db2mag.com/db_area/archives/2001/q1/hayes.shtml\n"
   if($sortOverflowsPerTotalSort>3.0);

print $outFH "\n";


# Lock Calculations
#------------------------------------------------------------------
if($lockTimeWait==0) {
   $lockTimePerLock=0;
} elsif($lockTimeWait ne "Not Collected") {
   $lockTimePerLock=$lockWaits/$lockTimeWait;
} else {
   $lockTimePerLock="not collected";
}
$lockLockPerTrans=0;
$lockLockPerTrans=$lockWaits/$transTotal
   if($transTotal);

# Print results
print $outFH "Locks:\n";
print $outFH "  Current: $lockCurrent\n";
print $outFH "  Total: $lockWaits\n";
print $outFH "  Average Time per Lock (ms): $lockTimePerLock\n";
print $outFH "  Average Lock per Transaction: $lockLockPerTrans\n";
print $outFH "  Deadlocks: $lockDeadlocks\n";
print $outFH "  Escalations: $lockEscalations\n";

print $outFH "\n";


# Package cache info
#------------------------------------------------------------------
print $outFH "Package cache:\n";
print $outFH "  Lookups: $packageCacheLookups\n";
print $outFH "  Inserts: $packageCacheInserts\n";
print $outFH "  Overflows: $packageCacheOverflows\n";

print $outFH "NOTICE: Package overflows should be zero.\n" .
             "        Increase PCKCACHESZ to prevent overflows\n"
   if($packageCacheOverflows>0);


END:
# Clean up after ourselves
if($opt_d && !$opt_s) {
   unlink $tempFilename if(-f $tempFilename);
}

# vim: sw=3 ts=3 expandtab
