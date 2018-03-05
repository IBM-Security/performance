#!/usr/bin/perl

# perfanalyze_audit_grep.pl
# Author: Casey Peel (cpeel@us.ibm.com)
# Last Updated: 2008/03/06 1715 MST
# Summary:
#    Greps stanzas out of an ITDS audit log
# Description:
#    This script reads in an ITDS audit log and greps stanzas out.
#    This is useful for isolating traffic to specific clients based
#    on IP or bind DNs.
#
#    This script takes an ITDS audit log as input.
#    See the ITDS documentation for enabling the audit log.
#


use Getopt::Std;

# Debug?
$Debug=0;

getopts('i:o:hnvq') or usage();
usage() if($opt_h);
$searchString=pop @ARGV;

# Print Usage and exit
sub usage {
   print STDERR <<EOF

Usage: $0 [ -i inputFile ] [ -o outputFile ] [ -h ] [ -v | -n ] searchString

Search hints:
  * Bind DN: search on the bind DN using: "bindDN: <DN>"
  * Operations: search on operations using one of the following followed by --:
      Search, Bind, Unbind, Add, Modify, Delete
    for example: Search--
  * Client IP: search on the client IP by using: "client: <ip:port>"
  * Connection: search on the connection ID by using: "connectionID: <num>"
  * Time: search on a time in the format: 2006-06-14-04:12:24.952-06:00DST
      Hint: to limit times to completed times, prefix with "--":
         --2006-06-14-04:12:24.952-06:00DST
      Hint: to limit to received times, prefix with "received:":
         received: 2006-06-14-04:12:24.952-06:00DST
  * Status: search on result status using one of the following:
      --Success, --No such object, --Sizelimit Exceeded

Search options:
  -n - case insensitive search (sorry, -i was already taken)
  -v - negative search, find stanzas that do not match the criteria

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
$caseInsensitive=0;
$invertSearch=0;

$caseInsensitive=$opt_n if($opt_n);
$invertSearch=$opt_v if($opt_v);

# need to have something to search on
if($searchString eq "") {
   print STDERR "A search string is required, exiting.\n";
   exit 1;
}


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
print STDERR "processing audit log (invertSearch: $invertSearch, caseInsensitive: $caseInsensitive)\n";

$stanza="";
while($line=<$fileHandle>) {
   $line=~s/\r//g;
   # we found the start to a stanza, process the previous one
   if($line=~/^AuditV/) {
      processStanza($stanza);
      $stanza="";
   }
   $stanza.=$line;
}

if($stanza) { processStanza($stanza); }

sub processStanza {
   my ($stanza) = @_;

   if(!$invertSearch) {
      if(($caseInsensitive && $stanza=~/\Q$searchString\E/i) || (!$caseInsensitive && $stanza=~/\Q$searchString\E/)) {
         # we found a stanza we're interested in
         print $outputFileHandle $stanza;
      }
   } else {
      if(!(($caseInsensitive && $stanza=~/\Q$searchString\E/i) || (!$caseInsensitive && $stanza=~/\Q$searchString\E/))) {
         # we found a stanza we're interested in
         print $outputFileHandle $stanza;
      } 
   }
}
