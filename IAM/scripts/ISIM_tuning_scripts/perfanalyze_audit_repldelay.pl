#!/usr/bin/perl

# perfanalyze_audit_repldelay.pl
# Author: Casey Peel (cpeel@us.ibm.com)
# Last Updated: 2007/09/20 1205 MDT
# Summary:
#    Determines how long replication took by analyzing two
#    audit logs, one for each server.
# Description:
#    This script reads in two ITDS audit logs from two machines in
#    a replication configuration taken during the same time.
#    It tries to see how long replication took between two machines
#    and returns some ballpark figures.
#
# NOTE:
#    This tool is limited by what information is provided in the audit
#    log -- use at your own risk, buyer beware, etc, etc.
#
#    This script takes ITDS audit logs as input.
#    See the ITDS documentation for enabling the audit log.
#


use Getopt::Std;
use POSIX;

# Debug?
$DEBUG=0;

getopts('m:r:t:b:o:uh') or usage();
usage() if($opt_h);

# Print Usage and exit
sub usage {
   print STDERR <<EOF

Usage: $0 [ -o outputFile ] [ -t timeSkew ] [ -u ] [ -h ] -m inputFile1 -r inputFile2
Files:
  -m - first ITDS audit log (generally the master)
  -r - second ITDS audit log (generally the replica)

Processing options:
  -b - processing block size lower number will use less memory (default: 100)
  -t - time skew between the two machines in seconds (default: 0)
       Note: can include fractions of a second: 1.459

Display options:
  -u - show all unmatched DNs

Other options:
  -h - displays this help information
  -o - file to put the processed results in, default is STDOUT

EOF
;
   exit;
}

# Initialize options
$timeSkew=0;
$showUnmatched=0;
$blockSize=100;

$timeSkew=$opt_t if($opt_t);
$showUnmatched=1 if($opt_u);
$file1=$opt_m;
$file2=$opt_r;
$blockSize=$opt_b if($opt_b);

# Default input is STDIN and output is STDOUT
$outputFileHandle=*STDOUT;

# Open the file to put the output in, if necessary
if($opt_o) {
   open OUTPUT, ">$opt_o" || die("Unable to open $opt_o for writing\n");
   $outputFileHandle=*OUTPUT;
}

# open both files for reading
open INPUT1, $file1 or die "Unable to open $file1\n";
open INPUT2, $file2 or die "Unable to open $file2\n";

# print status indicator
print STDERR "processing audit logs";

# to try and minimize memory usage, we'll process each input file in blocks
$finishedFile1=$finishedFile2=0;
while(!$finishedFile1 || !$finishedFile2) {
   $finishedFile1=processBlock(*INPUT1,1) if(!$finishedFile1);
   $finishedFile2=processBlock(*INPUT2,2) if(!$finishedFile2);
   print STDERR ".";
}

print STDERR "\n";

if($showUnmatched) {
   print "DNs in $file1 that are not in $file2:\n";
   foreach $entryDN (sort keys %{$entryHash{1}}) {
      print "   $entryDN\n";
   }

   print "DNs in $file2 that are not in $file1:\n";
   foreach $entryDN (sort keys %{$entryHash{2}}) {
      print "   $entryDN\n";
   }
} else {
   $missing1=scalar(keys %{$entryHash{1}});
   $missing2=scalar(keys %{$entryHash{2}});
   print "Info: There are $missing1 entries in $file1 that do not exist in $file2.\n" if($missing1);
   print "Info: There are $missing2 entries in $file2 that do not exist in $file1.\n" if($missing2);
}

# caluclate times
$timeSum=0;
$timeMin="initial";
$timeMax="initial";
$timeAvg="undef";
$count=0;
foreach $time (@replTimes) {
   $count++;
   $timeSum+=$time;
   $timeMax=$time if($timeMax < $time || $timeMax=="initial");
   $timeMin=$time if($timeMin > $time || $timeMin=="initial");
}
$timeAvg=$timeSum/$count if($count);

print "Replication times (in seconds):\n";
print "   Num: $count (update requests only)\n";
print "   Min: $timeMin\n";
print "   Max: $timeMax\n";
print "   Avg: $timeAvg\n";


# now for supporting functions

# function to process a block of lines from an audit log
# returns 1 if we've reached the end of the file
sub processBlock {
   my ($fileHandle,$fileNum) = @_;
   my $blockIndex=0;
   OUTER: while($line=<$fileHandle>) {
      $line=$stanzaSave{$fileHandle} . $line if($stanzaSave{$fileHandle});
      # if we're looking at an audit line, do some parsing on it
      if($line=~/^AuditV/) {
         # we found the start to a stanza, loop until we hit the end of it
         $stanza=$line;
         while($line=<$fileHandle>) {
            if($line=~/^AuditV/) {
               processStanza($stanza,$fileNum);
               $blockIndex++;
               if($blockIndex==$blockSize) {
                  $stanzaSave{$fileHandle}=$line;
                  return 0;
               } else {
                  undef $stanzaSave{$fileHandle};
                  redo OUTER;
               }
            }
            $stanza.=$line;
         }
      }
   }
   processStanza($stanza,$fileNum);
   return 1;
}


# function to process a stanza
# it is possible for the master audit log to see two update before the
# replica sees the first one, so we have to keep track of all updates
# that don't have matches, we do this with a stack
# logic is this:
#    have we seen this object in the other file yet?
#      if yes, calculate the time difference
#      if no, push the time on a stack
# to reduce memory overhead, we remove the entire hash entry
# if it's stack is empty
sub processStanza {
   my($stanza,$fileNum)=@_;
   my $entryDN;
   if($fileNum==1) { $otherFileNum=2; }
   else { $otherFileNum=1; }
   
   print STDERR "DEBUG: processingStanza\n" if($DEBUG);

   # only worry about stanzas that are updates
   return if(!($stanza=~/Modify--/ || $stanza=~/Add--/ || $stanza=~/Delete--/));
   
   # calculate the time
   if($stanza=~/--(\d+)-(\d+)-(\d+)-(\d+):(\d+):(\d+)(.\d+).+received: (\d+)-(\d+)-(\d+)-(\d+):(\d+):(\d+)(.\d+)/) {
      $receivedTime=mktime($13,$12,$11,$10,$9,$8-1900) + $14;
   }

   $stanza=~/^object: (.*)$/m;
   $entryDN=normalizeDN($1);

   return if($entryDN=~/^\s*$/);
      
   # if we've seen this query in the other file, get the time difference
   if(exists($entryHash{$otherFileNum}{$entryDN})) {
      $timeDiff=abs((shift @{$entryHash{$otherFileNum}{$entryDN}}) - $receivedTime)-$timeSkew;
      delete $entryHash{$otherFileNum}{$entryDN} if(scalar(@{$entryHash{$otherFileNum}{$entryDN}})==0);
      push @replTimes, $timeDiff;
   }
   # otherwise, just push it onto the stack that we've seen this one
   else {
      push @{$entryHash{$fileNum}{$entryDN}}, $receivedTime;
   }
}

# quick and easy normalize function
# converts everything to lowercase
# and tries to take care of spacing issues
sub normalizeDN {
   my($DN)=@_;
   $DN=~s/\s+,\s+/,/g;
   $DN=~tr/A-Z/a-z/;
   return $DN;
}

# vim: sw=3 ts=3 expandtab
