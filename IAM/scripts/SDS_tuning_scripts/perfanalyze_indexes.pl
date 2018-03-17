#!/usr/bin/perl

# perfanalyze_indexes.pl
# Author: Casey Peel (cpeel@us.ibm.com)
# Last Updated: 2006/05/04 1000 CDT
# Description:
#    Analyzes dynamic sql snapshots or audit logs for missing
#    indexes.
# Usage:
#    This output takes either a dynamic sql snapshot or an
#    audit log in addition to the schema files for the server.
#    You can get a dynamic sql snapshot by running:
#       db2 get snapshot for dynamic sql on DBNAME
#    You can get an audit log by turning on auditing in
#    the LDAP server.

use Getopt::Std;
use POSIX;

getopts('i:d:o:c:s:r:ha');

# Debug?
$DEBUG=0;

# Print Usage and exit
if($opt_h) {
   print <<EOF

Usage: $0 [ -c confFile | -d schemaDir | -s schemaFiles | -r remoteHost ] [ -i inputFile ] [ -o outputFile ] [ -a ]
Schema options:
  -c - fully qualified path name to ibmslapd.conf file
  -d - directory where schema files are located
  -s - semicolon separated list of schema files (no spaces)
  -r - remote host to pull schema from

Other options:
  -i - file containing dynamic sql statements or audit log for processing
  -o - file to put the processed results in, default is STDOUT
  -a - print all attributes searched on, not just unindexed ones

Note: use unix-style slashes for all files and directories, even if on Windows
If no arguments are given, the program will read input from STDIN.

EOF
;
exit;
}

# default schema files
@defaultSchemaFiles=qw(V3.system.at V3.ibm.at V3.user.at V3.config.at V3.system.oc V3.ibm.oc V3.user.oc V3.config.oc V3.modifiedschema);

# ldapdb2 tables to ignore
@ldapdb2TablesToIgnore=qw(SYSINDEXES SYSCOLUMNS LDAP_ENTRY LDAP_DESC REPLICAID SRC REPLCHANGE REPLCSTAT REPLSTATUS LDAP_GRP_DESC ACLPERM MEMBERGROUP REPLMIGRATE ENTRYOWNER);
foreach $table (@ldapdb2TablesToIgnore) { $tableIgnoreHash{$table}=1; }

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
   $fileHandle=*STDIN;
}

# Default output file is STDOUT
$outputFileHandle=*STDOUT;

# Unbuffer $outputFileHandle
select((select($outputFileHandle), $|=1)[0]);

# Open the file to put the output in, if necessary
if($opt_o) {
   open OUTPUT, ">$opt_o" || die("Unable to open $opt_o for writing\n");
   $outputFileHandle=*OUTPUT;
}

# read the ibmslapd.conf file, if given
if($opt_c) {
   open CONFFILE, $opt_c || die("Unable to open $opt_c for reading\n");
   while($line=<CONFFILE>) {
      chomp($line);
   
      if($line=~/^ibm-slapdIncludeSchema:\s(.*)$/ ||
         $line=~/^ibm-slapdSchemaAdditions:\s(.*)$/) {
         print STDERR "DEBUG: pushed schema to array: $1\n" if($DEBUG);
         push @schemaFiles, $1;
      }
   }
   close CONFFILE;
   
   # get the path to the ibmslapd.conf file so we can process the schema files themselves
   $confPath=$opt_c;
   $confPath=~s/ibmslapd.conf//;
}

# use the default files if a directory is given
if($opt_d) {
   @schemaFiles=@defaultSchemaFiles;
   $confPath=$opt_d;
}

# they've given us a list of schema files (either with or without a conf file
# or directory) so push them onto our list
if($opt_s) {
   print "DEBUG: manual schema files: $opt_s\n" if($DEBUG);
   push @schemaFiles, split ';', $opt_s;
}

# no directory or conf file? die!
if(!$opt_c && !$opt_d && !$opt_s && !$opt_r) {
   warn("WARNING: No configuration file (-c), directory (-d), list of schema files (-s), or a remote server to read from (-r) was specified, this is probably in error.\n");
}

# try to process each schema file
# Notes: file paths may be relative to install path so we'll try a couple
# of different things before totally giving up
foreach $schemaFile (@schemaFiles) {
   $schemaPath="";
   
   # absolute path or current directory?
   if(-f $schemaFile) {
      $schemaPath=$schemaFile ;
   } elsif(-f "$confPath/$schemaFile") {
      # relative path to conf file?
      $schemaPath="$confPath/$schemaFile";
   } elsif(-f "$confPath/../$schemaFile") {
      # relative to dir before conf file?
      $schemaPath="$confPath/../$schemaFile";
   } elsif(-f "/program files/ibm/ldap$schemaFile") {
      # some hard-coded places to look...
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
if($opt_r) {
   print STDERR "reading schema from $opt_r, this may take a while....\n";
   $netLDAPAvail = eval { require Net::LDAP; 1; };

   # if the module isn't available, die
   if(!$netLDAPAvail) {
      print "\n";
      print "Net::LDAP module not installed, this module is required with the -r option.\n";
      print "With ActivePerl (ie: perl on Windows) you can use ppm to install it:\n";
      print "   Start -> Run -> 'ppm'\n";
      print "   At the prompt, type: install perl-LDAP\n";
      print "On unix, use CPAN:\n";
      print "   perl -MCPAN -e shell\n";
      print "   At the prompt, type: install Net::LDAP\n";
      print "\n";
      exit(1);
   }
   
   $ldap = Net::LDAP->new($opt_r);
   $ldap->bind;
   $searchHandle = $ldap->search(base => "cn=schema",
                                 scope => "base",
                                 filter => "objectclass=*", 
                                 attrs => ["attributetypes","ibmattributetypes"]);
   foreach $entry ($searchHandle->entries) {
      processSchema($entry->get_value("attributetypes"));
      processSchema($entry->get_value("ibmattributetypes"));
   }
   $ldap->unbind;
}

sub processSchema {
   my @schemaArray=@_;
   foreach $line (@schemaArray) {
      chomp($line);
      
      # system schema & V3.modifiedschema processing:
      # samples:
      #   ( 1.3.6.1.4.1.12704.2.1 NAME 'eridiservice' SUP top MUST ( erCategory $ erpassword $ erservicename $ eruid $ erurl $ namingcontexts ) MAY ernamingattribute )
      #   ( 1.3.6.1.4.1.6054.1.1.10 DBNAME ( 'erObjectProfileName' 'erObjectProfileName' ) EQUALITY )
      #   attributetypes=( 2.5.4.3 NAME ( 'cn'  'commonName'  ) DESC 'This is the X.500 commonName attribute, which contains a name of an object.  If the object corresponds to a person, it is typically the persons full name.' SUP 2.5.4.41 EQUALITY 2.5.13.2 ORDERING 2.5.13.3 SUBSTR 2.5.13.4 USAGE userApplications )
      #   IBMAttributetypes=( 2.5.4.3 DBNAME( 'cn'  'cn' ) ACCESS-CLASS normal LENGTH 256 EQUALITY ORDERING SUBSTR APPROX )
      # we need to keep track of the attribute's OIDs since the indexing is done
      # on the OID and not the attribute (since the tablename may be truncated if the attribute
      # name is over 16 characters)
      # Since we can process statements as well as audit logs, we need to keep track of
      # the table -> attribute mappings too
      if($line=~/\(\s*(.*?)\s+NAME\s*\(*\s*'(\w+)'/i) {
         $oid=$1;
         $attrName=$2;
         $attrName=~tr/A-Z/a-z/; # make sure the attrname is lowercase for consistency
         $attrHash{$oid}=$attrName;
         $attrIndexed{$attrName}=0;
      }
      if($line=~/\(\s*(.*?)\s+DBNAME\s*\(*\s*'(\w+)'/i) {
         $oid=$1;
         $tableName=$2;
         $tableName=~tr/a-z/A-Z/; # make sure the tablename is uppercase for consistency
         $attrName=$attrHash{$oid};
         $tableHash{$tableName}=$attrName;
         if($line=~/EQUALITY/ || $line=~/SUBSTR/ || $line=~/ORDERING/ || $line=~/APPROX/) {
            $attrIndexed{$attrName}=1;
            print STDERR "DEBUG: found indexed attr: $attrName, tableName: $tableName\n" if($DEBUG);
         }
      }
   }
}

# it's possible we didn't find a single indexed attribute, that's probably an error
# lets warn someone
if(!scalar keys %attrIndexed) {
   warn("WARNING: Unable to find any indexed value. Reading schema probably failed, report will be inaccurate.\n");
}

# print status indicator
print STDERR "processing input file";

# pull the statements/filters from the file
$processedLineCount=0;
while($line=<$fileHandle>) {   
   chomp($line);
   $line=~s/\r//;
   
   # if it's a snapshot, we'll see this
   if($line=~/^ Statement text\s+= (.*)$/i) {
      push @statements, $1;
      $statementHash{$1}=$numExec;
      $processedLineCount++;
      print STDERR "." if($processedLineCount%1000==0);
   }
   
   # keep track of number of executions to generate seen count
   # but only if it's a number (ie: being monitored)
   if($line=~/^ Number of executions\s+= (.*)$/i) {
      $numExec=$1;
      $numExec=0 if($numExec!~/^\d+$/);
   }
   
   # if it is an audit log, we'll see this
   if($line=~/^filter:\s*(.*)$/i) {
      push @filters, $1;
      $processedLineCount++;
      print STDERR "." if($processedLineCount%1000==0);
   }
}

# print a newline to break from our status
print STDERR "\n";

# let the user know if we didn't find anything
if(scalar(@filters)+scalar(@statements)==0) {
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
foreach $statement (@statements) {
   # if it isn't a select, we're not interested
   next if($statement!~/select/i);

   $origStatement=$statement;
   # first, nuke all _T's (for truncated) in the statement
   $statement=~s/_T//g;
   # next, nuke all word characters before periods (like D. from D.AEID)
   $statement=~s/\w+\.(\w+)/$1/g;
   # now pull out all table names
   while($statement=~/FROM\s+(\w+)/i) {
      $tableName=$1;
      $statement=~s/FROM\s+$tableName//ig;
      $tableName=~tr/a-z/A-Z/; # make sure the tablename is uppercase for consistency

      # skip tables we should ignore
      next if($tableIgnoreHash{$tableName});

      print STDERR "DEBUG: found table: $tableName, attribute: $tableHash{$tableName}\n" if($DEBUG);
      $usedAttributesHash{$tableHash{$tableName}}+=$statementHash{$origStatement};
   }   
}

# next, pull out attributes from any filters
foreach $filter (@filters) {
   $filter=~s/=[^)]+/=/g;
   
   # equals
   while($filter=~/(\w+)([<>]*=)/) {
      $attribute=$1;
      $filter=~s/$attribute$2//;
      
      print STDERR "DEBUG: found attribute: $attribute\n" if($DEBUG);
      $usedAttributesHash{$attribute}++;
   }
}

# finally, see which of the attributes used doesn't have an index
print $outputFileHandle "Printing only unindexed attributes\n" if(!$opt_a);
print $outputFileHandle "Note: 'Seen count' may not be completely accurate for dynamic sql snapshots\n";
printf $outputFileHandle "  %-20s  %5s  %s\n", "Attribute", "Seen", "Index status";
foreach $attribute (sort keys %usedAttributesHash) {
   # if the attribute is blank, skip it - this generally happens when
   # analysing a snapshot and we find system tables
   next if($attribute=~/^$/);

   if($attrIndexed{$attribute}) {
      $symbol='+';
      $status="Indexed";
   }
   if(!$attrIndexed{$attribute}) {
      # at this point we just know we don't have an index
      # it is possible that we've never seen it at all in the schema files
      # in which case it won't be in our hash at all so test for the existance
      if(exists($attrIndexed{$attribute})) {
         $symbol='-';
         $status="NOT Indexed";
      } else {
         $symbol='?';
         $status="Unknown, not found in schema files";
      }
   }
   
   if($symbol ne '+' || $opt_a) {
      printf $outputFileHandle "%s %-20s  %5s  %s\n", $symbol, $attribute, $usedAttributesHash{$attribute}, $status;
   }
}