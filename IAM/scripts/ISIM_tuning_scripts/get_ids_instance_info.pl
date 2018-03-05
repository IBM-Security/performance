#!/usr/bin/perl -w

use strict;
use Getopt::Long;

# Written by Lidor Goren (lidor@us.ibm.com)

# Prints out the IBM Directory Server Instance information for the instance installed under the only, current, or specified user


my $output; #'cn,location,version,env:LDAP_MAXCARD,env:IBMSLAPD_USE_SELECTIVITY';
my $user = getpwuid($<) || $ENV{USER} || getlogin();
our $quiet = 0;
my $help = 0;
my $RC = &GetOptions( "o|output=s"            => \$output,
		      "u|user=s"              => \$user,
		      "q|quiet"               => \$quiet,
                      "h|help"                => \$help,
                    );

if ( !$RC || $help ) {
  &usage;
  exit 0;
}

if (not defined $output) {
  warn "Please define desired output using the -o|output switch.";
  &usage;
  exit 1;
}

my @output = split(/,/, $output);

# First step, determine location of idsinstances.ldif
my @path_list = ('/opt/ibm/ldap/idsinstinfo/idsinstances.ldif', '/opt/IBM/ldap/idsinstinfo/idsinstances.ldif');
my @l = @path_list;
my $ids_instances_file = shift @path_list;
if ((! &isReadableFile($ids_instances_file)) && (@path_list)) { $ids_instances_file = shift @path_list; }
if (! &isReadableFile($ids_instances_file)) {
  warn 'Could not open any of the ISDS instance files:\n';
  foreach my $path (@path_list) {
    warn "$path\n";
  }
  exit 11;
}

# Now collect information on all instances mentioned in idsinstances.ldif
my $string;
{
  # Unset $/, the Input Record Separator, to make <> give you the whole file at once
  local $/=undef;
  open FILE, $ids_instances_file or die "Couldn't open $ids_instances_file: $!";
  $string = <FILE>;
  close FILE;
}
my @matches = ( $string =~ /dn: cn=(.+), CN=IDS INSTANCES\ncn: \1\nids-instanceDesc: [^\n]+\nids-instanceLocation: ([^\n]+)\nids-instanceVersion: ([^\n]+)\nobjectClass: TOP\nobjectClass: ids-instance\n/g );
my @instances = ();
while (@matches) {
  my ($cn, $location, $version) = splice @matches, 0, 3;
  push @instances, {
    'cn'       => $cn,
    'location' => $location,
    'version'  => $version,
  }
}

# Now we need to select the correct instance. If there is only one, no problem.
# If there are several, see if there's one that matches the current (or specified) user
# If none match, print out all available instances and prompt the user to select one via the -u|user switch
my $ids_instance;
if ((scalar @instances) == 1) {
  $ids_instance = $instances[0];
  &log("Found a single ISDS instance:\n");
  &log("cn=$ids_instance->{'cn'}   location=$ids_instance->{'location'}    version=$ids_instance->{'version'}\n");
} else {
  &log("Found these ISDS instances:\n");
  my $i = 1;
  my $index;
  foreach my $instance (@instances) {
    &log("$i: cn=$instance->{'cn'}   location=$instance->{'location'}    version=$instance->{'version'}\n");
    if ( $instance->{'cn'} eq $user ) { $index = $i }
    $i++;
  }
  if (defined $index) {
    $ids_instance = $instances[$index-1];
    &log("Based on user, automatically selected the following instance:\n");
    &log("$index: cn=$ids_instance->{'cn'}   location=$ids_instance->{'location'}    version=$ids_instance->{'version'}\n");
  } else {
    if ($quiet) {
      warn("Found these ISDS instances:\n");
      my $i = 1;
      foreach my $instance (@instances) {
	warn("$i: cn=$instance->{'cn'}   location=$instance->{'location'}    version=$instance->{'version'}\n");
	$i++;
      }
    }
    warn "Please select desired instance by specifying user via the -u switch\n";
    exit 12;
  }
}

# Produce the requested output
my $ids_env;
foreach my $out (@output) {
  if ( $out =~ /^env:(.+)/ ) {
    my $var = $1;
    if (not defined $ids_env) {
      $ids_env = {};
      # Now we read the selected instance's configuration file ibmslapd.conf
      my $instance_dir = "$ids_instance->{'location'}/idsslapd-$ids_instance->{'cn'}";
      my $config_file = "$instance_dir/etc/ibmslapd.conf";
      if (! &isReadableFile($config_file)) {
	warn "Could not open $config_file";
	exit 13;
      }
      open FILE, $config_file or die "Couldn't open $config_file: $!";
      my $in_front_end_config = 0;
      while ( my $line = <FILE> ) {
	if ( $in_front_end_config ) {
	  if ( $line =~ /^ibm-slapdSetenv: (.+)=(.+)$/ ) { $ids_env->{$1} = $2 }
	  if ( $line =~ /^dn:/ ) { $in_front_end_config = 0; last; }
	} else {
	  if ( $line =~ /^dn: cn=Front End, cn=Configuration$/ ) { $in_front_end_config = 1 }
	}
      }
      close FILE;
    }
    if (exists $ids_env->{$var}) { print "$ids_env->{$var}\n" } else { print "UNSET\n" }
  } else {
    print "$ids_instance->{$out}\n"
  }
}





exit 0;

sub usage {
  print "\n";
  print "Prints out the IBM Directory Server Instance information for the instance installed under the only, current, or specified user\n";
  print "\n";
  print "get_ids_instance_info.pl -o <output> [-u|user <user>] [-q|quiet] [-h|help]\n";
  print "\n";
  print "<output> - Comma separated list of outputs. Choose from the following:\n";
  print "           cn\n";
  print "           location\n";
  print "           version\n";
  print "           env:LDAP_MAXCARD\n";
  print "           env:IBMSLAPD_USE_SELECTIVITY\n";
  print "\n";
  print "Example:\n";
  print "\n";
  print "get_ids_instance_info.pl -q -o \"version,env:LDAP_CARD,env:IBMSLAPD_USE_SELECTIVITY\"\n\n";
}

sub isReadableFile {
  my $file = shift @_;
  if ((-e $file) && (-f $file) && (-r $file)) { return 1 } else { return 0 }
}

sub log {
  our $quiet;
  if ( !$quiet ) {
    my $string = shift @_;
    print $string;
  }
}
