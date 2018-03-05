#!/usr/bin/perl

# dynsqlsumm2advisworkload.pl
# Author: Casey Peel (cpeel@us.ibm.com)
# Last Updated: 2007/09/27 1447 MDT
# Desription:
#   Perl script that takes a the output of perfanalyze_dynamicsql.pl
#   (which in turn uses a  db2 dynamic SQL snapshot) and creates a
#   workload file that can be used by the db2advis tool. The workload
#   will include all the queries found in the perftune_dynamnicsql.pl
#   output and the frequency they were encountered.
#
#   This is useful for letting DB2 suggest possible indexes given
#   the actual queries and frequency.
#
# Usage:
#   perfanalyze_dynamicsql.pl -i snapshot | dynsumm2advisworkload.pl > workload.sql

# Example input/output:
# Input:
#    0.1314        27  UPDATE itimuser.ACTIVITY SET RESULT_SUMMARY = ? WHERE ID = ? AND RESULT_SUMMARY = ?
# Output:
#    --#SET FREQUENCY 27
#    UPDATE itimuser.ACTIVITY SET RESULT_SUMMARY = ? WHERE ID = ? AND RESULT_SUMMARY = ?

while($line=<STDIN>) {
   $line=~s/\r//;
   chomp($line);
   if($line=~/^\s*\d+\.\d+\s+(\d+)\s+(.*)$/) {
      print "--#SET FREQUENCY $1\n";
      print "$2;\n";
   }
}

