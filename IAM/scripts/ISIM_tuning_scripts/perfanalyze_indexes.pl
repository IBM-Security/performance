#!/usr/bin/perl

# perfanalyze_indexes.pl
# Author: Casey Peel (cpeel@us.ibm.com)
# Last Updated: 2010/06/15 1346 MDT
# Summary:
#    Analyzes DB2 dynamic sql snapshots, ITDS audit logs, or Sun ONE access
#    logs for missing indexes.
# Description:
#    This takes either a dynamic sql snapshot, an TDS audit log, output
#    from the perfanalyze_dynamicsql.pl script, output from the 
#    perfanalyze_audit.pl script, a Sun ONE access log, even a list of
#    attributes one per line (whatever you have handy) in addition to the
#    schema files for the server. The schema files can be obtained either
#    by telling the script where the ibmslapd.conf file is found (-c), the
#    directory in which the schema files are located (-d), a list of schema
#    files to parse (-s), a remote server to read the schema from directly
#    (-r), or a combination thereof.
#
#    Reading the schema from the server is easiest but requires that the
#    Net::LDAP perl module be installed. If the module is not installed the
#    script gives some hints on how to install it.
#
#    You can get an audit log by turning on auditing in the LDAP server.
#
#    You can get a dynamic sql snapshot by running:
#       db2 connect to DBNAME
#       db2 get snapshot for dynamic sql on DBNAME
#    or
#       db2 connect to DBNAME
#       db2 get snapshot for all on DBNAME
#    as the ITDS database owner.
#
# NOTE: Just because an attribute is unindexed and searched on does NOT by
# itself mean that it should be indexed. Only index frequently searched on
# attributes that are poorly performing. Use the perfanalyze_audit.pl script
# for query timing analysis.

use Getopt::Std;
use strict;

# Debug?
our $DEBUG=0;

our %options;

getopts('i:d:o:c:s:r:u:p:l:t:k:ha', \%options) or usage();
usage() if($options{h});

#----------------------------------------------------------------------------
# Global variables

# ITDS default schema files
our @defaultSchemaFiles=qw(V3.system.at V3.ibm.at V3.user.at V3.config.at V3.system.oc V3.ibm.oc V3.user.oc V3.config.oc V3.modifiedschema);

# database tables to ignore, probably an incomplete list
our @databaseTablesToIgnore=qw(SYSINDEXES SYSCOLUMNS LDAP_ENTRY LDAP_DESC REPLICAID SRC REPLCHANGE REPLCSTAT REPLSTATUS LDAP_GRP_DESC ACLPERM MEMBERGROUP REPLMIGRATE ENTRYOWNER SYS SYSBUFFERPOOLS SYSDATATYPES SYSDEPENDENCIES SYSFUNCMAPPINGS SYSINDEXOPTIONS SYSNODEGROUPDEF SYSROUTINES SYSSERVERS SYSTABLES SYSTRIGGERS SYSTYPEMAPPINGS SYSUSEROPTIONS SYSWRAPPERS COLDIST COLGROUPS COLUMNS INDEXES TABLES BUFFERPOOLS);
our %tableIgnoreHash;
foreach my $table (@databaseTablesToIgnore) { $tableIgnoreHash{$table}=1; }

our %origAttrHash;
our %oidHash;
our %isAttributeIndexed;
our %ldifAttributeHash;
our %ldifIBMAttributeHash;
our %filterHash;
our %statementHash;
our %tableHash;
our %usedAttributesHash;

#----------------------------------------------------------------------------
# Supporting functions

# Print Usage and exit
sub usage {
   print STDERR <<EOF

Usage: $0 [ -c confFile | -d schemaDir | -s schemaFiles | -r remoteHost [ -u username | -p password ] | -k ddlFile ] [ -t ldapType ] [ -i inputFile ] [ -o outputFile ] [ -l ldifFile ] [ -a ]
Schema options:
  -c - fully qualified path name to ibmslapd.conf file
  -d - directory where schema files are located
  -s - colon separated list of schema files (no spaces)
  -r - remote host to pull schema from; to specify a port besides 389,
       append it to the end of the host: ldap.example.com:489
  -u - username (if not specified, bind will be anonymous)
  -p - password
  -k - file containing "db2look -d [dbname] -e" output
  -t - type of LDAP server, either ITDS (default) or SUNONE

Output options:
  -a - print all attributes searched on, not just unindexed ones
  -l - file to export an LDIF file for use in indexing any unindexed attributes

Other options:
  -i - file containing DB2 dynamic sql statements, ITDS audit log,
       Sun ONE access log, or list of attributes
  -o - file to put the processed results in, default is STDOUT

Note: use unix-style slashes for all files and directories, even if on Windows
If no arguments are given, the program will read input from STDIN.

EOF
;
exit;
}

sub slurpFile {
   my ($filename) = @_;
   local $/ = undef;

   open SLURPFILE, $filename or die("WARNING: Unable to open $filename.\n");
   my $totalFile=<SLURPFILE>;
   close SLURPFILE;

   return $totalFile;
}

sub collapseDDL {
   my ($totalFile) = @_;
   $totalFile =~ s/^(--[^\n]*)\n/\1\[NL\]/mg;
   $totalFile =~ s/(;)\n/$1\[NL\]/mg;
   $totalFile =~ s/^\s*$/\[NL\]/mg;
   $totalFile =~ s/\n/ /g;
   $totalFile =~ s/\s+/ /g;
   $totalFile =~ s/\Q[NL]\E/\n/g;
   $totalFile =~ s/^\s+//mg;
   $totalFile =~ s/ , /, /g;

   return $totalFile;
}

our %attrHash;
sub processSchema {
   my @schemaArray=@_;
   foreach my $line (@schemaArray) {
      chomp($line);
      
      # ITDS system schema & V3.modifiedschema processing:
      # samples:
      #   ( 1.3.6.1.4.1.12704.2.1 NAME 'eridiservice' SUP top MUST ( erCategory $ erpassword $ erservicename $ eruid $ erurl $ namingcontexts ) MAY ernamingattribute )
      #   ( 1.3.6.1.4.1.6054.1.1.10 DBNAME ( 'erObjectProfileName' 'erObjectProfileName' ) EQUALITY )
      #   attributetypes=( 2.5.4.3 NAME ( 'cn'  'commonName'  ) DESC 'This is the X.500 commonName attribute, which contains a name of an object.  If the object corresponds to a person, it is typically the persons full name.' SUP 2.5.4.41 EQUALITY 2.5.13.2 ORDERING 2.5.13.3 SUBSTR 2.5.13.4 USAGE userApplications )
      #   IBMAttributetypes=( 2.5.4.3 DBNAME( 'cn'  'cn' ) ACCESS-CLASS normal LENGTH 256 EQUALITY ORDERING SUBSTR APPROX )

      # Sun ONE sample from cn=schema
      # attributeTypes: ( 1.3.6.1.4.1.6054.1.1.69 NAME 'erHost'  EQUALITY 2.5.13.1 SYNTAX 1.3.6.1.4.1.1466.115.121.1.12 SINGLE-VALUE X-ORIGIN 'user defined' )
      # attributeTypes: ( 2.5.4.3 NAME ( 'cn' 'commonName' ) DESC 'Standard LDAP attribute type' SUP name SYNTAX 1.3.6.1.4.1.1466.115.121.1.15 X-ORIGIN 'RFC 2256')

      # For ITDS:
      #   we need to keep track of the attribute's OIDs since the indexing is
      #   done on the OID and not the attribute (since the tablename may be
      #   truncated if the attribute name is over 16 characters for some
      #   combinations of ITDS and DB2). Since we can process statements as
      #   well as audit logs, we need to keep track of the table -> attribute
      #   mappings too
      if($line=~/\(\s*(.*?)\s+NAME\s+\(?\s*'(\w+)'/i) {
         my $oid=$1;
         my $attrName=$2;
         $origAttrHash{$oid}=$attrName;
         $attrName=~tr/A-Z/a-z/; # make sure the attrname is lowercase for consistency
         $attrHash{$oid}=$attrName;
         $oidHash{$attrName}=$oid;
         $isAttributeIndexed{$attrName}=0;
         
         # if they want to create an LDIF for indexing, store the data we have
         if($options{l}) {
            $line=~/^[^(]*(\(.+\))[^(]*$/;
            $ldifAttributeHash{$attrName}=$1;
         }
      }
      if(($options{t} eq "ITDS" && $line=~/\(\s*(.*?)\s+DBNAME\s*\(*\s*'(\w+)'/i) ||
         ($options{t} eq "SUNONE" && $line=~/\(\s*(.*?)\s+NAME\s+\(?\s*'(\w+)'.*SYNTAX/i)) {
         my $oid=$1;
         my $tableName=$2;
         $tableName=~tr/a-z/A-Z/; # make sure the tablename is uppercase for consistency
         my $attrName=$attrHash{$oid};
         $tableHash{$tableName}=$attrName;
         if($line=~/EQUALITY/ || $line=~/SUBSTR/ || $line=~/ORDERING/ || $line=~/APPROX/) {
            $isAttributeIndexed{$attrName}=1;
            print STDERR "DEBUG: found indexed attr: $attrName, tableName: $tableName\n" if($DEBUG);
         }
         
         # if they want to create an LDIF for indexing, store the data we have
         if($options{l} && $options{t} eq "ITDS") {
            $line=~/^[^(]*(\(.+\))[^(]*$/;
            $ldifIBMAttributeHash{$attrName}=$1;
         }
      }
   }
}

#----------------------------------------------------------------------------
# Start of main processing


# validate the LDAP server type
$options{t} = "ITDS" if(!$options{t});
if($options{t} ne "ITDS" && $options{t} ne "SUNONE") {
   die("ERROR: Invalid LDAP type: $options{t}. Valid types: ITDS, SUNONE\n");
}

# currently we only support checking SunONE attributes via Net::LDAP
if($options{t} eq "SUNONE" && (!$options{r} || $options{c} || $options{d} || $options{s})) {
   die("ERROR: When running againt Sun ONE, only the -r option is supported for reading in the schema.\n");
}

# Open an existing file if one is given
our $inputFileHandle;
if($options{i}) {
   if(-f $options{i}) {
      open INPUT, $options{i} || die("Unable to open file $options{i}\n");
      $inputFileHandle=*INPUT;
   } else {
      die("Unable to open file $options{i}\n");
   }
}

# Default input is STDIN
if(!$inputFileHandle) {
   print STDERR "no input file specified (-i), reading input from STDIN\n";
   print STDERR "Hint: use the -h option to get the usage statement\n";
   $inputFileHandle=*STDIN;
}

# Default output file is STDOUT
our $outputFileHandle=*STDOUT;

# Open the file to put the output in, if necessary
if($options{o}) {
   open OUTPUT, ">$options{o}" || die("Unable to open $options{o} for writing\n");
   $outputFileHandle=*OUTPUT;
}

# Unbuffer $outputFileHandle
select((select($outputFileHandle), $|=1)[0]);

our $confPath;
our @schemaFiles;

# read the ibmslapd.conf file, if given
if($options{c}) {
   open CONFFILE, $options{c} || die("Unable to open $options{c} for reading\n");
   while(my $line=<CONFFILE>) {
      chomp($line);
   
      if($line=~/^ibm-slapdIncludeSchema:\s(.*)$/ ||
         $line=~/^ibm-slapdSchemaAdditions:\s(.*)$/) {
         print STDERR "DEBUG: pushed schema to array: $1\n" if($DEBUG);
         push @schemaFiles, $1;
      }
   }
   close CONFFILE;
   
   # get the path to the ibmslapd.conf file so we can process the schema
   # files themselves
   $confPath=$options{c};
   $confPath=~s/ibmslapd.conf//;
}

# use the default files if a directory is given
if($options{d}) {
   @schemaFiles=@defaultSchemaFiles;
   $confPath=$options{d};
}

# they've given us a list of schema files (either with or without a conf file
# or directory) so push them onto our list
if($options{s}) {
   print STDERR "DEBUG: manual schema files: $options{s}\n" if($DEBUG);
   push @schemaFiles, split ':', $options{s};
}

# no directory or conf file? warn!
if(!$options{c} && !$options{d} && !$options{s} && !$options{r} && !$options{k}) {
   warn("WARNING: No configuration file (-c), directory (-d), list of schema files (-s), remote server to read from (-r), or db2look output (-k) was specified, this is probably in error.\n");
}

# try to process each schema file
# Notes: file paths may be relative to install path so we'll try a couple
# of different things before totally giving up
foreach my $schemaFile (@schemaFiles) {
   my $schemaPath="";
   
   # absolute path or current directory?
   if(-f $schemaFile) {
      $schemaPath=$schemaFile;
   }
   # relative path to conf file?
   elsif(-f "$confPath/$schemaFile") {
      $schemaPath="$confPath/$schemaFile";
   }
   # relative to dir before conf file?
   elsif(-f "$confPath/../$schemaFile") {
      $schemaPath="$confPath/../$schemaFile";
   }
   # some hard-coded places to look...
   elsif(-f "/program files/ibm/ldap$schemaFile") {
      $schemaPath="/program files/ibm/ldap$schemaFile";
   }

   # throw a warning and skip it if we still can't find it
   if(! -f $schemaPath) {
      print $outputFileHandle "WARNING: Unable to open $schemaFile, skipping...\n";
      next;
   }
   
   # open it and process it
   print STDERR "processing schema file: $schemaPath...\n";
   open SCHEMAFILE, $schemaPath or die("Unable to open $schemaPath");
   # yes, yes - I know reading entire files into an array and processing
   # it is about the worst-scaling thing you can do, but this lets me get
   # away with a single mechanism to process both files and online schemas
   # so I'm willing to let you, the gentle script user, take the hit, sorry.
   processSchema(<SCHEMAFILE>);
   close SCHEMAFILE;
}

# if they want to read it from a remote server, do that
if($options{r}) {
   print STDERR "reading schema from $options{r}, this may take a while....\n";
   my $netLDAPAvail = eval { require Net::LDAP; 1; };

   # if the module isn't available, die
   if(!$netLDAPAvail) {
      print STDERR "\n";
      print STDERR "Net::LDAP module not installed, this module is required with the -r option.\n";
      print STDERR "With ActivePerl (ie: perl on Windows) you can use ppm to install it:\n";
      print STDERR "   Start -> Run -> 'ppm'\n";
      print STDERR "   At the prompt, type: install perl-LDAP\n";
      print STDERR "On Linux systems, try to install it via your package manager:\n";
      print STDERR "   On RHEL systems as root:\n";
      print STDERR "      yum install perl-LDAP\n";
      print STDERR "On other Unix systems, use CPAN:\n";
      print STDERR "   perl -MCPAN -e shell\n";
      print STDERR "   At the prompt, type: install Net::LDAP\n";
      print STDERR "\n";
      exit(1);
   }
   
   my $ldap = Net::LDAP->new("ldap://$options{r}");

   # if we can't connect, let the user know that
   die("ERROR: Unable to create LDAP connection to $options{r}\n") if(!$ldap);

   # if a user is specified, log in as them
   my $result;
   if($options{u}) {
      $result = $ldap->bind($options{u}, password => $options{p});
   }
   # otherwise, bind anonymously
   else {
      $result = $ldap->bind;
   }

   # if the bind failed, print an error and die
   die("ERROR: " . $result->error() . "\n") if($result->is_error());

   my $searchHandle = $ldap->search(base => "cn=schema",
                                 scope => "base",
                                 filter => "objectclass=*", 
                                 timelimit => 0,
                                 sizelimit => 0,
                                 attrs => ["attributetypes","ibmattributetypes"]);

   # if the search failed, print an error and die
   die("ERROR: " . $result->error() . "\n") if($result->is_error());

   foreach my $entry ($searchHandle->entries) {
      processSchema($entry->get_value("attributetypes"));
      processSchema($entry->get_value("ibmattributetypes"));
   }
   $ldap->unbind;
}

if($options{k}) {
   if($options{l}) {
      print "WARNING: -l parameter isn't available when processing db2look output.\n";
      undef $options{l};
   }

   my $oid=0;
   foreach my $line ( split(/\n/, collapseDDL( slurpFile($options{k}) )) ) {
      if($line=~/^CREATE TABLE ".*?"."(.*?)"/) {
         my $attrName=$1;
         my $oid="0.0.0.0." . ($oid++);
         $origAttrHash{$oid}=$attrName;
         $attrName=~tr/A-Z/a-z/; # make sure the attrname is lowercase for consistency
         $isAttributeIndexed{$attrName}=0;
      }
      if($line=~/^CREATE INDEX.* ON ".*?"."(.*?)" (\(.*?\))/) {
         my $tableName=$1;
         my $indexDef=$2;

         # all attribute tables have indexes on EID, so don't count this one
         if($indexDef ne q#("EID" ASC)#) {
            $tableName=~tr/a-z/A-Z/; # make sure the tablename is uppercase for consistency
            my $attrName=$tableName;
            $attrName=~tr/A-Z/a-z/; # make sure the attrname is lowercase for consistency
            $tableHash{$tableName}=$attrName;
            $isAttributeIndexed{$attrName}=1;
         }
      }
   }
}

# it's possible we didn't find a single indexed attribute, that's probably an
# error lets warn someone
if(!scalar keys %tableHash) {
   warn("WARNING: Unable to find any indexed attributes. Reading schema probably failed, report will be inaccurate.\n");
   warn("WARNING: You may need to specify a username (-u) and password (-p) to pull the schema from some LDAP severs, particularly for ITDS 6.x.\n") if($options{r});
}

# print status indicator
print STDERR "processing input file";

# pull the statements/filters from the file
my $processedLineCount=0;
my $numExec;
while(my $line=<$inputFileHandle>) {
   $line=~s/[\n\r]+//;
   
   # if it is an ITDS audit log or SunONE access log, we'll see one of these 
   if($line=~/^filter:\s*(.*)$/i ||
      $line=~/filter="([^"]+)"/) {
      $filterHash{$1}++;
      $processedLineCount++;
      print STDERR "." if($processedLineCount%1000==0);
   }

   # if it's a snapshot, we'll see this
   elsif($line=~/^ Statement text\s+= (.*)$/i) {
      $statementHash{$1}=$numExec;
      $processedLineCount++;
      print STDERR "." if($processedLineCount%1000==0);
   }
   
   # keep track of number of executions to generate seen count
   # but only if it's a number (ie: being monitored)
   elsif($line=~/^ Number of executions\s+= (.*)$/i) {
      $numExec=$1;
      $numExec=0 if($numExec!~/^\d+$/);
   }
   
   # if it is the output from a perfanalyze_dynamicsql.pl script we'll see this
   elsif($line=~/^\s+\d+\.\d+\s+(\d+)\s+(\w.*)$/) {
      $statementHash{$2}=$1;
   }
   # or this
   elsif($line=~/^\s+N\/A\s+(\d+)\s+(\w.*)$/) {
      $statementHash{$2}=$1;
   }
   
   # if it is the output from a perfanalyze_audit.pl script we'll see this
   elsif($line=~/^\s+\d+\.\d+\s+(\d+)\s+(\(.*\))$/) {
      $filterHash{$2}=$1;
   }

   # if they just gave us a file with a list of attributes, one on each line,
   # we'll see this
   elsif($line=~/^(\w+)$/) {
      $filterHash{"($1=*)"}++;
   }
}

# print a newline to break from our status
print STDERR "\n";

# let the user know if we didn't find anything
if(scalar(keys %filterHash) + scalar(keys %statementHash)==0) {
   die("No filters or statements were found in the input, no analysis done.\n");
}

# pull the searched-upon attributes out of the statements and filters
# first, pull out attributes from the statements
# Samples (originally all on one line):
#    SELECT distinct D.DEID
#      FROM ADTAMPRB.LDAP_DESC AS D
#     WHERE D.AEID=? AND D.DEID IN
#          (SELECT EID FROM ADTAMPRB.UID
#            WHERE UID_T = ?)
#    SELECT distinct D.DEID
#      FROM ADTAMPRB.LDAP_DESC AS D
#     WHERE D.AEID=? AND D.DEID IN
#         ((SELECT EID
#             FROM ADTAMPRB.OBJECTCLASS
#            WHERE OBJECTCLASS = ?)
#           INTERSECT
#          (SELECT EID
#             FROM ADTAMPRB.REPLICAID
#            WHERE REPLICAID = ?))
# WARNING: we may be missing something, consider statements beta for a while...
foreach my $statement (keys %statementHash) {
   # if it isn't a select, we're not interested
   next if($statement!~/select/i);
   
   my $origStatement=$statement;
   # first, nuke all _T's (for truncated) in the statement
   $statement=~s/_T//g;
   # next, nuke all word characters before periods (like D. from D.AEID)
   $statement=~s/\w+\.(\w+)/$1/g;
   # nuke all double spaces
   $statement=~s/\s+/ /g;
   
   # now pull out all table names
   while($statement=~/FROM\s+(\w+)/i) {
      my $tableName=$1;
      $statement=~s/FROM\s+$tableName//ig;
      $tableName=~tr/a-z/A-Z/; # make sure the tablename is uppercase for consistency

      # skip tables we should ignore
      next if($tableIgnoreHash{$tableName});

      if($tableHash{$tableName} ne "") {
         $usedAttributesHash{$tableHash{$tableName}}+=$statementHash{$origStatement};
      } else {
         $usedAttributesHash{$tableName}+=$statementHash{$origStatement};
      }
   }
}

# next, pull out attributes from any filters
foreach my $filter (keys %filterHash) {
   my $origFilter=$filter;
   $filter=~s/=[^)]+/=/g;
   
   # equals
   while($filter=~/(\w+)([<>]*=)/) {
      my $attribute=$1;
      $filter=~s/$attribute$2//;
      
      print STDERR "DEBUG: found attribute: $attribute\n" if($DEBUG);
      $usedAttributesHash{$attribute}+=$filterHash{$origFilter};
   }
}

# finally, see which of the attributes used doesn't have an index
print $outputFileHandle "Printing only unindexed attributes\n" if(!$options{a});

# print notes if we're processing a dynamic sql snapshot
if(scalar %statementHash) {
   print $outputFileHandle "Notes when using Dynamic SQL snapshots: \n";
   print $outputFileHandle "  1) 'Seen' may not be completely accurate\n";
   print $outputFileHandle "  2) Names in ALL CAPS were pulled from the snapshot and may not be actual LDAP attributes\n";
}
# or if we're pulling the schema from a db2look output
if($options{k}) {
   print $outputFileHandle "Using db2look output for schema basis is a run-at feature, user beware.\n";
}

# print the header
printf $outputFileHandle "\n  %-20s  %8s  %s\n", "Attribute", "Seen", "Index status";
print $outputFileHandle ('-' x 70) . "\n";
our $unindexedAttributesFound=0;

# now print out each attribute
foreach my $attribute (sort keys %usedAttributesHash) {
   my $normalizedAttribute=$attribute;
   my $symbol;
   my $status;

   $normalizedAttribute=~tr/A-Z/a-z/;
   if($isAttributeIndexed{$normalizedAttribute}) {
      $symbol='+';
      $status="Indexed";
   }
   if(!$isAttributeIndexed{$normalizedAttribute}) {
      $unindexedAttributesFound++;
      # at this point we just know we don't have an index
      # it is possible that we've never seen it at all in the schema files
      # in which case it won't be in our hash at all so test for the existance
      if(exists($isAttributeIndexed{$normalizedAttribute})) {
         $symbol='-';
         $status="NOT Indexed";
      } else {
         $symbol='?';
         $status="Unknown, not found in schema";
      }
   }
   
   if($symbol ne '+' || $options{a}) {
      printf $outputFileHandle "%s %-20s  %8s  %s\n", $symbol, $attribute, $usedAttributesHash{$attribute}, $status;
   }
   
}

if($unindexedAttributesFound==0 && !$options{a}) {
   print $outputFileHandle "No unindexed or unknown attributes found. Run with the all (-a) flag to see all attributes and/or check your input files.\n";
}

if($unindexedAttributesFound && $options{l}) {
   # create SYNTAX -> EQUALITY match hash
   my %syntaxHash=(
      "1.3.6.1.4.1.1466.115.121.1.7"  => "booleanMatch",
      "1.3.6.1.4.1.1466.115.121.1.12" => "distinguishedNameMatch",
      "1.3.6.1.4.1.1466.115.121.1.15" => "caseIgnoreMatch",
      "1.3.6.1.4.1.1466.115.121.1.27" => "integerMatch",
      "1.3.6.1.4.1.1466.115.121.1.40{128}" => "octetStringMatch",
   );

   # if they want an LDIF to index the unindexed values, create it
   open LDIFFILE, ">$options{l}" or die("Unable to open $options{l} for writing\n");
   print LDIFFILE <<EOF
#
# This file was generated by: $0
# for LDAP server type: $options{t}
#
# The stanzas in the file attempt to index unindexed attributes
# by adding an EQUALITY index to each identified attribute.
# The EQUALITY index may or may not be the index that you need.
EOF
;
   if($options{t} eq "SUNONE") {
      print LDIFFILE <<EOF
#
# Sun ONE requires specifying the OID or name of the matching
# algorithm used. The LDIF below attempts to guess which OID
# to used based on the SYNTAX of the attribute. If it can't
# guess it will use __EQUALITY_MATCH__ instead.
#
EOF
;
   }

   print LDIFFILE <<EOF
# You should confirm this LDIF does what you want before
# running it!
#
# Usage:
#   ldapmodify -h <host> -p <port> -D cn=root -w <password> -f $options{l}
#

EOF
;
   foreach my $attribute (sort keys %usedAttributesHash) {
      my $normalizedAttribute=$attribute;
      $normalizedAttribute=~tr/A-Z/a-z/;
      # if the attribute is blank, skip it - this generally happens when
      # analysing a snapshot and we find system tables
      next if($normalizedAttribute=~/^$/);
   
      # we only want to index unindexed attributes
      next if($isAttributeIndexed{$normalizedAttribute} || !exists($isAttributeIndexed{$normalizedAttribute}));

      my $attrLine;
    
      if($options{t} eq "ITDS" && $ldifIBMAttributeHash{$normalizedAttribute}) {
         $attrLine=$ldifIBMAttributeHash{$normalizedAttribute};
         $attrLine=~s/\)$/ EQUALITY )/;
      } elsif($options{t} eq "ITDS") {
         $attrLine="( " . $oidHash{$normalizedAttribute} . " DBNAME ( '" . $origAttrHash{$oidHash{$normalizedAttribute}} . "'  '" . $origAttrHash{$oidHash{$normalizedAttribute}} . "' ) EQUALITY )";

      } elsif($options{t} eq "SUNONE" && $ldifAttributeHash{$normalizedAttribute}) {
         $attrLine=$ldifAttributeHash{$normalizedAttribute};
         my $equalityLine="EQUALITY __EQUALITY_MATCH__";
         $attrLine=~/SYNTAX\s+(.*?)\s+/;
         my $syntaxOID=$1;
         if(exists($syntaxHash{$syntaxOID})) {
            my $equalityMatch=$syntaxHash{$syntaxOID};
            $equalityLine=~s/__EQUALITY_MATCH__/$equalityMatch/;
         }
         $attrLine=~s/SYNTAX/$equalityLine SYNTAX/;
      } else {
         die("ERROR: Unable to create LDIF, sorry.\n");
      }

      if($options{t} eq "ITDS") {
         print LDIFFILE <<EOF
# attribute: $normalizedAttribute
dn: cn=schema
changetype: modify
replace: attributetypes
attributetypes: $ldifAttributeHash{$normalizedAttribute}
-
replace: ibmattributetypes
ibmattributetypes: $attrLine

EOF
;
      } else {
         print LDIFFILE <<EOF
# attribute: $normalizedAttribute
dn: cn=schema
changetype: modify
replace: attributetypes
attributetypes: $attrLine

EOF
;
      }
   }
   
   close LDIFFILE;
   
   print $outputFileHandle "\nLDIF file $options{l} created to index unindexed attributes.\n";
}

# vim: sw=3 ts=3 expandtab
