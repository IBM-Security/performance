#!/usr/bin/perl -w

# Written by Lidor Goren (lidor@us.ibm.com)

# This script will compare two version numbers of the form x[.y[.z[..]]]
# and print out 1 if the first version is equal to or higher than the second

use strict;
use Getopt::Long;

my $help = 0;
my $RC = &GetOptions( "h|help"                => \$help,
                    );

if ( !$RC || $help || ((scalar @ARGV)!=2) ) {
  &usage;
  exit 0;
}

my ($v1, $v2) = @ARGV;

my @v1 = split(/\./, $v1);
my @v2 = split(/\./, $v2);

while (@v1 && @v2) {
  my $e1 = shift @v1;
  my $e2 = shift @v2;
  if ($e1 > $e2) { &return_true(); }
  if ($e1 < $e2) { &return_false(); }
}

if (@v2) { &return_false(); } else { &return_true(); } 

sub return_true {
  print 1;
  exit 0;
}

sub return_false {
  print 0;
  exit 0;
}

sub usage {
  print "This script will compare two version numbers of the form x[.y[.z[..]]]\n";
  print "and print out 1 if the first version is equal to or higher than the second\n\n";
  print "compare_versions.pl <ver1> <ver2>\n\n";
  print "E.g. compare_versions.pl 6.3 6.31\n";
}


exit 0;

