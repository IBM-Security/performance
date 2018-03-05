#!/usr/bin/perl

# perfanalyze_audit_replay.pl
# Author: Casey Peel (cpeel@us.ibm.com)
# Last Updated: 2008/10/23 1518 MST
# Summary:
#    Replays ITDS audit logs
# Description:
#    This script reads an audit log and replays any searches in the log, regardless
#    of how long they took to execute or how much data they return. It can do this
#    either by creating a file containing ldapsearch commands or by executing
#    the searches directly on the server.
#
#    Executing directly against the server is easiest but requires that the Net::LDAP perl
#    module be installed. If the module is not installed the script gives some hints
#    for how to install it.
#
#    You can get an audit log by turning on auditing in the ITDS server.
#
#    Known limitations:
#    * The audit log does not store information on result size limits so the script
#      is unable to include this information and will pull back all the results.
#    * This script does not recognize or replicate controlTypes, such as server-side
#      sorting or paging. Because it does not recognize paging each subsequent page
#      request will be reproduced as another search. It is recommended that you use
#      perfanalyze_audit.pl to determine if paging is used in searches and if so
#      remove them using perfanalyze_audit_grep.pl before replaying them against your
#      server. 

use Getopt::Std;

# Debug?
$Debug=0;

getopts('i:s:r:p:b:D:w:h') or usage();
usage() if($opt_h);

# Print Usage and exit
sub usage {
   print STDERR <<EOF

Usage: $0  [ -r remoteHost | -p portNum | -s scriptFile ] [ -i inputFile ] [ -b bindFile | -D username | -w password ]
Binding options:
  Unless specified, the search will be performed anonymously. Use -D/-w to
  set a default username to bind as. If you pass a bindFile in with -b it
  will try to use those passwords when it finds matching bind IDs in the file.
  -b - file with username:password pairs for binding
  -D - bind username
  -w - bind password
  -r - remote host to run against directly (or host for ldapsearch string)
       Default: localhost
  -p - port to connect to (or port for ldapsearch string)
       Default: 389

Output options:
  -s - file to output ldapsearch script in

Other options:
  -i - file containing dynamic sql statements or audit log for processing

If no arguments are given, the program will read input from STDIN.

Specifying the -s will create a file instead of contacting the server
directly.
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
   print STDERR "no file specified, reading input from STDIN\n";
   print STDERR "Hint: use the -h option to get the usage statement\n";
   $fileHandle=*STDIN;
}

# Default output file is STDOUT
$outputFileHandle=*STDOUT;

# Unbuffer $outputFileHandle
select((select($outputFileHandle), $|=1)[0]);

# process the bindFile if provided
if($opt_b) {
   open BINDFILE, "$opt_b";
   while($line=<BINDFILE>) {
      chomp($line);
      $line=~/(.*):(.*)/;
      $bindHash{$1}=$2;
   }
   close BINDFILE;
}

# set the default connection options
$host=$opt_r || "localhost";
$port=$opt_p || 389;

# set the default binding options
if($opt_D || $opt_w) {
   $defaultUsername=$opt_D;
   $defaultPassword=$opt_w;
}

# script file specified? let them know
if($opt_s) {
   open LDAPSEARCH, ">$opt_s" or die("Unable to open $opt_s for writing\n");
   print STDERR "creating script file $opt_s against $host:$port\n";
} else {
   print STDERR "no script file specified (-s), will contact host $host:$port directly\n";
   print STDERR "Note: some of these queries may take a long time to execute\n";
}


# print status indicator
print STDERR "processing input file";

# Sample:
# AuditV2--2005-09-20-10:50:55.797-06:00DST--V3 Search--bindDN: cn=Directory Manager--client: 10.33.22.33:6048--connectionID: 8338--received: 2005-09-20-10:50:55.796-06:00DST--Success
# controlType: 2.16.840.1.113730.3.4.2
# criticality: false
# base: 
# scope: baseObject
# derefAliases: neverDerefAliases
# typesOnly: false
# filter: (objectclass=*)

$filterCount=0;
$stanza="";
# pull the data from the file
while($line=<$fileHandle>) {
   $line=~s/\r//g;
   # we found the start to an ITDS stanza, process the previous one
   if($line=~/^AuditV/) {
      $recordCount++;
      print STDERR "." if($opt_s && !($filterCount % 10000));
      processITDSStanza($stanza);
      $stanza="";
   }
   $stanza.=$line;
}

# take care of the last stanza in the file
processITDSStanza($stanza) if($stanza);

$ldap="";

sub processITDSStanza {
   my ($stanza) = @_;
   my $bindDN, $filter, $base, $scope, $attributes, $aliases;

   # we are only interested in the search records
   if($stanza=~/ Search--/mi) {
      # pull in specific values
      $bindDN=$1 if($stanza=~/--bindDN: (.*?)--/);
      $filter=$1 if($stanza=~/^filter: (.*)$/mi);
      $base=$1 if($stanza=~/^base: (.*)$/mi);

      if($stanza=~/^scope: (.*)$/m) {
         $scope=$1;
      
         # convert audit.log strings to ldapsearch strings
         if($scope eq "baseObject") {
            $scope="base";
         } elsif($scope eq "singleLevel") {
            $scope="one";
         } elsif($scope eq "wholeSubtree") {
            $scope="sub";
         }
      }

      if($stanza=~/^attributes: (.*)$/m) {
         $attributes=$1;
         $attributes=~s/,//g;
      }

      if($stanza=~/^derefAliases: (.*)$/m) {
         $aliases=$1;

         # convert audit.log strings to ldapsearch strings
         if($aliases eq "neverDerefAliases") {
            $aliases="never";
         } elsif($aliases eq "derefAlways") {
            $aliases="always";
         }
         # need: "search" and "find"
      }

      # get the right bindDN and bindPW
      if(exists $bindHash{$bindDN}) {
         $bindPW=$bindHash{$bindDN};
      } elsif($defaultPassword!~/^$/) {
         $bindDN=$defaultUsername;
         $bindPW=$defaultPassword;
      } else {
         $bindDN=$bindPW="";
      }

      # if they want to create a script, do that
      if($opt_s) {
         if($bindDN!~/^$/) {
            $bindString="-D $bindDN -w $bindPW";
         }

         print LDAPSEARCH qq(ldapsearch $bindString -h $host -p $port -b "$base" -s $scope -a $aliases "$filter" $attributes\n);
         print STDERR "." if(!($filterCount % 1000));
         $filterCount++;
      } else {
      # otherwise we try to contact the host
         $netLDAPAvail = eval { require Net::LDAP; 1; };
      
         # if the module isn't available, die
         if(!$netLDAPAvail) {
            print STDERR "\n";
            print STDERR "Net::LDAP module not installed, this module is required to contact the server directly.\n";
            print STDERR "With ActivePerl (ie: perl on Windows) you can use ppm to install it:\n";
            print STDERR "   Start -> Run -> 'ppm'\n";
            print STDERR "   At the prompt, type: install perl-LDAP\n";
            print STDERR "On unix, use CPAN:\n";
            print STDERR "   perl -MCPAN -e shell\n";
            print STDERR "   At the prompt, type: install Net::LDAP\n";
            print STDERR "\n";
            exit(1);
         }
         
         # only bind at the beginning (!$ldap) and 
         # when the binding user changes $prevBindDN!=$bindDN
         if($prevBindDN!=$bindDN || !$ldap) {
            $ldap->unbind() if($ldap);
            $ldap = Net::LDAP->new($opt_r, port => $opt_p);
            if($bindDN) {
               $ldap->bind($bindDN, password => $bindPW);
               print STDERR "\nbinding as $bindDN\n";
               print STDERR "running queries";
            } else {
               $ldap->bind();
               print STDERR "\nbinding anonymously\n";
               print STDERR "running queries";
            }
            $prevBindDN=$bindDN;
         }
         
         # Note that the search calls the searchCallback function
         # to process each entry as it comes back. The searchCallback
         # function trashes the entry so we don't waste a lot of memory.
         $searchHandle = $ldap->search(base => $base,
                                       scope => $scope,
                                       deref => $aliases,
                                       filter => $filter, 
                                       attrs => (split ' ', $attributes),
                                       callback => \&searchCallback);
         $searchHandle->abandon;
         print STDERR ".";
      }
   }
}

print STDERR "\ndone\n";

# disconnect from the server
$ldap->unbind if($ldap);

if($opt_s) {
   close LDAPSEARCH;
}

# this is a "dummy" callback function. Since we just want to execute the query
# but aren't concerned about the results, this just trashes whatever we get
# back instead of keeping it in memory
sub searchCallback {
   my ($mesg,$entry) = @_;
   $mesg->pop_entry if(defined($entry));
}

# vim: sw=3 ts=3 expandtab
