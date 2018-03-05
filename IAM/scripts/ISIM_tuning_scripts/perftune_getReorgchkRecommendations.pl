#!/usr/bin/perl

# perftune_getReorgchkRecommendations.pl
# Author: Casey Peel (cpeel@us.ibm.com)
# Last Updated: 2009/01/20 1444 MST
# Summary:
#    Parses the 'db2 reorgchk' output and pulls out tables that have been
#    recommended for a reorg.
# Description:
#    This script reads the output of a 'dbd2 reorgchk' and pulls out table
#    names for tables that have been identified by DB2 as needing a reorg.
#    Flagged tables are those with an asterisk in column F1, F2, or F3.
# Usage recommendation:
#    db2 reorgchk current statistics > /tmp/reorgchk.recs
#    cat /tmp/reorgchk.recs | perftune_getReorgchkRecommendations.pl SCHEMA > /tmp/reorgchk.tables
#    perftune_reorg.sh DATABASE SCHEMA `cat /tmp/reorgchk.tables`

use strict;

# The first argument to this script should be the schema name containing the
# tables you're interested in pulling out if you're passing the output
# directly into perftune_reorg.sh as it is expecting only the table name not
# the SCHEMA.TABLE name
my $schema=$ARGV[0];

my $table;

while(my $line=<STDIN>) {
   if($schema && $line=~/^Table:\s$schema\.(.*)$/i) {
      $table=$1;
   } elsif(!$schema && $line=~/^Table:\s(.*)$/i) {
      $table=$1;
   } elsif($table && $line=~/\s([-\*]{3})\s$/) {
      print "$table\n" if($1=~/\*/);
      undef $table;
   }
}
