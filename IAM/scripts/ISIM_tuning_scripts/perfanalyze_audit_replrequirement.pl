#!/usr/bin/perl

# perfanalyze_audit_replrequirement.pl
# Author: Casey Peel (cpeel@us.ibm.com)
# Last Updated: 2007/09/20 1222 MDT
# Summary:
#    Determines how tight replication consistency would have to be
#    for traffic in an audit log to still work.
# Description:
#    This script reads in an ITDS audit log and looks for any updates.
#    It then analyzes stanzas that occur after the updates to see if
#    another request comes in for that entry and if so, when it occurs.
#    It will produce a report listing the times between these events.
#
# NOTE:
#    This tool is limited by what information is provided in the audit
#    log -- use at your own risk, buyer beware, etc, etc.
#
#    This script takes an ITDS audit log as input.
#    See the ITDS documentation for enabling the audit log.
#


use Getopt::Std;
use POSIX;

# DEBUG?
$DEBUG=0;

getopts('i:o:s:h') or usage();
usage() if($opt_h);

# Print Usage and exit
sub usage {
   print STDERR <<EOF

Usage: $0 [ -i inputFile ] [ -o outputFile ] [ -h | -s scope ]
Output options:
  -s - scope resolution, determines if the consistency check is done
       on base, one, and/or subtree searches. scope can have the following
       values:
         base - most reliable (default)
         one  - includes base, next reliable
         sub  - includes one and base, least reliable

Other options:
  -h - displays this help information
  -i - file containing log for processing
  -o - file to put the processed results in, default is STDOUT

If no inputFile is given, the program will read input from STDIN.

EOF
;
   exit;
}

# Initialize options
$scopeResolution="base";

$scopeResolution=$opt_s if($opt_s);

# Default input is STDIN and output is STDOUT
$outputFileHandle=*STDOUT;

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

# Open the file to put the output in, if necessary
if($opt_o) {
   open OUTPUT, ">$opt_o" || die("Unable to open $opt_o for writing\n");
   $outputFileHandle=*OUTPUT;
}

# print status indicator
print STDERR "processing audit log\n";

printf $outputFileHandle "Output format:\n";
printf $outputFileHandle "%13s   %-15s   %s\n", "delay secs", "collision type", "object";

# we can't provide a per-stanza status indicator as all data is printed inline
# as we find it
$stanza="";
while($line=<$fileHandle>) {
   $line=~s/\r//g;
   # we found the start to a stanza, process the previous one
   if($line=~/^AuditV/) {
      $searchCount++;
      processStanza($stanza);
      $stanza="";
   }
   $stanza.=$line;
}

if($stanza) { processStanza($stanza); }

# global variables
$baseTimeString="";
$baseTime=0;

sub processStanza {
   my($stanza)=@_;
   my $entryDN;
   
   print STDERR "DEBUG: processingStanza\n" if($DEBUG);
   
   # calling mktime for every stanza is a major perf hit
   # hence the baseTime stuff below which is roughly 2x faster
   # for stanzas tightly-clustered in time (specifically hours)
   #      1  2  3  4  5  6 
   # --2005-12-20-13:48:14.455
   if($stanza=~/--(....)-(..)-(..)-(..):(..):(..\....)/) {
#   if($stanza=~/--received: (....)-(..)-(..)-(..):(..):(..\....)/) {
      if($baseTimeString ne "$1-$2-$3-$4") {
         $baseTime=mktime(0,0,$4,$3,$2,$1-1900);
         $baseTimeString="$1-$2-$3-$4";
      }
      $time=$baseTime+($5*60)+$6;
   }

   # see if it is an update operation or a search operation
   if($stanza=~/Modify--/) {
      $stanza=~/^object: (.*)$/m;
      $entryDN=normalizeDN($1);
      if(exists($entryHash{$entryDN}) && $addHash{$entryDN}) {
         handleCollision($entryDN,$entryHash{$entryDN},$time,"modify");
      }
      $entryHash{$entryDN}=$time;
      delete $addHash{$entryDN};
      print STDERR "DEBUG: Found modify: $entryDN - $time\n" if($DEBUG);
      @entryDNs=keys %entryHash;
   } elsif($staza=~/Add--/) {
      $stanza=~/^entry: (.*)$/m;
      $entryDN=normalizeDN($1);
      $entryHash{$entryDN}=$time;
      $addHash{$entryDN}=1;
      print STDERR "DEBUG: Found add: $entryDN - $time\n" if($DEBUG);
      @entryDNs=keys %entryHash;
   } elsif($staza=~/Delete--/) {
      $stanza=~/^entry: (.*)$/m;
      $entryDN=normalizeDN($1);
      if(exists($entryHash{$entryDN}) && $addHash{$entryDN}) {
         handleCollision($entryDN,$entryHash{$entryDN},$time,"delete");
      }
      $entryHash{$entryDN}=$time;
      delete $addHash{$entryDN};
      print STDERR "DEBUG: Found delete: $entryDN - $time\n" if($DEBUG);
      @entryDNs=keys %entryHash;
   } elsif($stanza=~/Search--/) {
      $stanza=~/^base: (.*)$/m; $searchBase=normalizeDN($1);
      $stanza=~/^scope: (.*)$/m; $searchScope=$1;
      
      print STDERR "DEBUG: Found search: $searchBase, $searchScope - $time\n" if($DEBUG);
      
      # search for entries that might collide
      # our search depends on the scope of the search
      if($searchScope eq 'baseObject' && ($scopeResolution eq "base" || $scopeResolution eq "one" || $scopeResolution eq "sub")) {
         # base level is easy, 'search' for existance
         if(exists($entryHash{$searchBase})) {
            handleCollision($searchBase,$entryHash{$searchBase},$time,"search: base");
            delete $entryHash{$searchBase};
            @entryDNs=keys %entryHash;
         }
      } elsif($searchScope eq 'singleLevel' && ($scopeResolution eq "one" || $scopeResolution eq "sub")) {
         # single level is a bit tricker with the regex in the grep
         @impactedEntries=grep(/^[^,]+,\Q$searchBase\E$/, @entryDNs);
         if(length(@impactedEntries)) {
            foreach $entry (@impactedEntries) {
               handleCollision($entry,$entryHash{$entry},$time,"search: one",$searchBase);
               delete $entryHash{$entry};
            }
            @entryDNs=keys %entryHash;
         }
      } elsif($searchScope eq 'wholeSubtree' && ($scopeResolution eq "sub")) {
         # subtree isn't that much harder than base, grep through the keys for anything that matches
         @impactedEntries=grep(/\Q$searchBase\E$/, @entryDNs);
         if(length(@impactedEntries)) {
            foreach $entry (@impactedEntries) {
               handleCollision($entry,$entryHash{$entry},$time,"search: sub",$searchBase);
               delete $entryHash{$entry};
            }
            @entryDNs=keys %entryHash;
         }
      }
   }
}

sub handleCollision {
   my($entryDN,$modifyTime,$searchTime,$type,$searchBase)=@_;
   $timeBetween=$searchTime-$modifyTime;
   $searchBase = "- search base: $searchBase" if($searchBase ne "");
   printf $outputFileHandle "%8.3f secs - %-15s - DN: %s %s\n", $timeBetween, $type, $entryDN, $searchBase;
}

sub normalizeDN {
   my($DN)=@_;
   $DN=~tr/A-Z/a-z/;
   return $DN;
}
