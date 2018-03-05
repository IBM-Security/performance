#!/usr/bin/perl

# perfcheck_tunings.pl
# Author: Casey Peel (cpeel@us.ibm.com)
# Last Updated: 2009/06/04 1509 MDT
# Summary:
#    Checks tunings provided by the collect*Data.[bat|sh] scripts
#    or the WAS collector.sh script.
# Description:
#    This script is designed to spot-check known problem areas
#    in ITDS, DB2, and WAS under ITIM.
#

use Getopt::Std;
use strict;

# DEBUG?
our $DEBUG=0;

# script global variables
our %dataFilenames = (
   db2 => [ "os.name", "db.name", "db2level.out", "db2set.out", "dbm.cfg", "db.cfg", "bufferpools.out", "cardinalities.out", "runstats_times.out", "snapshot.out", "tables.ddl" ],
   tds => [ "os.name", "id.out", "ulimit.out", "etc/ibmslapd.conf", "etc/V3.modifiedschema", "monitor.out", "audit.out" ],
   was => [ ],
);

our $tempDir = "./tempData";
our $dataDir;
our $dataFile;
our $dataType;

our %options;

our $productUsingDB2 = "";
our @productsUsingITDS = ();

#----------------------------------------------------------------------------
# Functions

# Print Usage and exit
sub usage {
   print STDERR <<EOF

Usage: $0 -i [ inputFile | inputDir ] [ -t dataType ]
Input Options
  -i - file or directory for processing
  -t - type of data file:
          db2 - default
          tds
          was

Other options:
  -h - displays this help information
  -k - keep the temporary extracted data directory instead of removing it

EOF
;
   exit;
}

sub confirmDataDir {
   my ($dataDir) = @_;

   # check to see that its actually a directory
   return 0 if(! -d $dataDir);

   # check to see if we have an os.name file
   return 1 if(-f "$dataDir/os.name");

   # check to see if we have a WAS collector output
   my @javaProperties = findFiles($dataDir, "Java\/Properties");
   return 1 if(-f pop @javaProperties);

   # otherwise, fail
   return 0;
}

sub findFiles {
   my ($baseDir, $search) = @_;

   my @returnFiles;

   opendir DIRINPUT, $baseDir;

   my @allFiles=sort readdir DIRINPUT;
   my @dirList;

   closedir DIRINPUT;

   foreach my $file (@allFiles) {
      next if($file=~/^\.$/ || $file=~/^\.\.$/);

      my $actualFile="$baseDir/$file";
      push @returnFiles, $actualFile if($actualFile=~/$search/);
      push @dirList, $actualFile if(-d $actualFile);
   }

   foreach my $dir (@dirList) {
       push @returnFiles, findFiles($dir, $search);
   }

   return @returnFiles;
}

sub slurpFile {
   my ($filename) = @_;
   local $/ = undef;

   open INPUT, $filename or warn("WARNING: Unable to open $filename.\n") && return "";
   my $totalFile=<INPUT>;
   close INPUT;

   # remove all carriage returns
   $totalFile=~s/\r//g;

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

sub isCardTuningEnabled {
   my ($totalFile, $table, $value) = @_;

   return (-1,0) if($totalFile !~ /\s+$table\s+/);

   if($totalFile =~ /$table\s+(\d+)/) {
      if($1 >= $value) {
         return (1,$1);
      } else {
         return (0,$1);
      }
   }

   return (0,0);
}

sub getLastRunstats {
   my ($totalFile, $table) = @_;

   return 0 if($totalFile !~ /\s+$table\s+/i);

   if($totalFile =~ /$table\s+([^\s]+)$/m) {
      return $1;
   }

   return -1;
}

#----------------------------------------------------------------------------
# Main function

getopts('i:d:t:kh', \%options) or usage();
usage() if($options{h} || !$options{i});

$dataType = $options{t};
$dataType="db2" if(!$dataType);

# if we were given an inputFile do some processing
if(-f $options{i}) {
   $dataFile=$options{i};

   # confirm we have a valid filename
   die("ERROR: $dataFile does not exist.\n") if(! -f $dataFile);

   # calculate the directory name based on the dataType
   if($dataType eq "was") {
      $dataDir=$tempDir;
   } else {
      $dataDir="$tempDir/${dataType}Data";
   }

   # check to ensure that the temp directory doesn't exist
   die("ERROR: $tempDir already exists, remove it before continuing.\n") if(-d $tempDir);

   # create the temp directory
   mkdir($tempDir);

   # copy the source file to the temp directory
   system("cp $dataFile $tempDir");
   $dataFile="$tempDir/$dataFile";

   # uncompress the file if necessary
   if($dataFile =~ /.gz$/i || $dataFile =~ /.tgz/i) {
      if(system("gunzip $dataFile") & 127) {
         die("ERROR: Unable to gunzip $dataFile.\n");
      } else {
         $dataFile =~ s/.gz$//i;
         $dataFile =~ s/.tgz$/.tar/i;
      }
   } elsif($dataFile =~ /.z$/i) {
      if(system("gunzip $dataFile") & 127) {
         die("ERROR: Unable to gunzip $dataFile.\n");
      } else {
         $dataFile =~ s/.z$//i;
      }
   } elsif($dataFile =~ /.bz2$/i) {
      if(system("bunzip2 $dataFile") & 127) {
         die("ERROR: Unable to bunzip2 $dataFile.\n");
      } else {
         $dataFile =~ s/.bz2$//i;
      }
   }

   # extract the data from the file
   if($dataFile =~ /.tar$/i) {
      if(system("tar xf $dataFile -C $tempDir") & 127) {
         die("ERROR: Unable to un-tar $dataFile.\n");
      }
   } elsif($dataFile =~ /.zip$/i || $dataFile =~ /.jar$/i) {
      # first try to unzip
      if(system("unzip -q $dataFile -d $tempDir") & 127) {
         # if that doesn't work, try to un-jar
         if(system("jar $dataFile -C $tempDir") & 127) {
            die("ERROR: Unable to un-jar or unzip $dataFile.\n");
         }
      }
   }
} else {
   $dataDir=$options{i};
}

# at this point we should have a directory full of data
die("ERROR: Data directory ($dataDir) does not exist. Something may have gone wrong during file extraction or you may have specified the wrong dataType (-t).") if(!confirmDataDir($dataDir));

# confirm we have the desired files and warn if any of them are missing
foreach my $filename (sort @{$dataFilenames{$dataType}}) {
   warn("WARNING: Expected to find $dataDir/$filename but it wasn't there.\n") if(! -f "$dataDir/$filename");
}

print "Entries marked with ATTENTION should be investigated.\n";

# do our checking
if($dataType eq "db2") {
   my $desiredMonitoringSetting = 1;
   my $someMonitoringEnabled = 0;

   # see if monitoring is enabled
   print "\nDatabase monitoring\n";
   if(-f "$dataDir/dbm.cfg") {
      my $fileContents = slurpFile("$dataDir/dbm.cfg");
      foreach my $monitor ("DFT_MON_BUFPOOL","DFT_MON_LOCK","DFT_MON_SORT","DFT_MON_STMT","DFT_MON_TIMESTAMP","DFT_MON_UOW") {
         if($fileContents =~ /\Q($monitor) = OFF\E/) {
            print "   ATTENTION: $monitor is not enabled but should be.\n";
         }
         $desiredMonitoringSetting = 0;
      }
      foreach my $monitor ("DFT_MON_TABLE") {
         if($fileContents =~ /\Q($monitor) = ON\E/) {
            print "   ATTENTION: $monitor is enabled but should not be.\n";
         }
         $desiredMonitoringSetting = 0;
      }
      if($desiredMonitoringSetting) {
         print "   Monitoring correctly enabled\n";
      }

      # see if any monitoring is enabled
      $someMonitoringEnabled = 1 if($fileContents =~ /DFT_MON\w+\) = ON/);
   } else {
      print "   WARNING: Unable to determine if database monitoring is enabled as dbm.cfg was not provided.\n";
   }

   # see if monitoring is active if it is enabled
   if($someMonitoringEnabled) {
      if(-f "$dataDir/snapshot.out") {
         my $fileContents = slurpFile("$dataDir/snapshot.out");
         # remove the "Not Collected" in the Table Snapshot
         $fileContents =~ s/Rows Read\s+=\s+Not Collected//g;
         if($fileContents =~ /Not Collected/i) {
            print "   ATTENTION: Some monitoring not active - bounce DB2 for the enabled monitoring to become active.\n";
         } else {
            print "   Monitoring is active\n";
         }
      } else {
         print "   WARNING: Unable to determine if database monitoring is active as snapshot.out was not provided.\n";
      }
   }

   # check for database indexes
   print "\nDatabase indexes\n";
   if(-f "$dataDir/tables.ddl") {
      my $fileContents = collapseDDL(slurpFile("$dataDir/tables.ddl"));

      my $foundProblems = 0;

      # if the file has a LDAP_DESC table, check for the LDAP_DESC indexes
      if($fileContents =~ /LDAP_DESC/) {
         $productUsingDB2 = "ITDS";

         # print an info blurb to ensure people don't overlook LDAP attribute indexes
         print "   HINT: Use perfanalyze_indexes.pl to find missing LDAP attribute indexes.\n";

         if($fileContents =~ /\Q"LDAP_DESC" ("AEID" ASC, "DEID" ASC)\E/) {
            print "   LDAP_DESC(AEID,DEID) index exists.\n";
         } else {
            print "   ATTENTION: LDAP_DESC(AEID,DEID) index does not exist.\n";
            $foundProblems = 1;
         }
      }

      # if it has an OBJECTCLASS table, check for the two OBJECTCLASS indexes
      if($fileContents =~ /OBJECTCLASS/) {
         if($fileContents =~ /\Q"OBJECTCLASS" ("EID" ASC, "OBJECTCLASS" ASC)\E/) {
            print "   OBJECTCLASS(EID,OBJECTCLASS) index exists.\n";
         } else {
            print "   ATTENTION: OBJECTCLASS(EID,OBJECTCLASS) does not exist.\n";
            $foundProblems = 1;
         }
         if($fileContents =~ /\Q"OBJECTCLASS" ("OBJECTCLASS" ASC, "EID" ASC)\E/) {
            print "   OBJECTCLASS(OBJECTCLASS,EID) index exists.\n";
         } else {
            print "   ATTENTION: OBJECTCLASS(OBJECTCLASS,EID) does not exist.\n";
            $foundProblems = 1;
         }
      }

      # show if no problems were found
      if(!$foundProblems) {
         print "   No problems found with indexes\n";
      }
   } else {
      print "   WARNING: Unable to determine index status as tables.ddl was not provided.\n";
   }

   # check for adjusted cardinailities indexes
   print "\nDatabase cardinalities\n";
   if(-f "$dataDir/cardinalities.out") {
      my $fileContents = slurpFile("$dataDir/cardinalities.out");
      my %desiredCardValues = ( "LDAP_ENTRY" => 9E18, "LDAP_DESC" => 9E18, "SECAUTHORITY" => 9E10, "ERPARENT" => 9E10, "PROCESS" => 50000, "ACTIVITY" => 50000, "PROCESSDATA" => 50000, "SCHEDULED_MESSAGE" => 50000 );
      foreach my $table (sort keys %desiredCardValues) {
         my $card = $desiredCardValues{$table};
         my ($cardEnabled, $card) = isCardTuningEnabled($fileContents, $table, $card);
         if($cardEnabled == 1) {
            print "   $table card adjustment applied (card = $card).\n";
         } elsif($cardEnabled == 0) {
            print "   ATTENTION: $table card adjustment not applied (card = $card).\n";
         }
      }

      if($fileContents =~ /\s+PROCESSDATA\s+/) {
         $productUsingDB2 = "ITIM";
      }

      if($fileContents =~ /\s+ERPARENT\s+/) {
         push @productsUsingITDS, "ITIM";
      }

      if($fileContents =~ /\s+SECAUTHORITY\s+/) {
         push @productsUsingITDS, "ITAM";

         my $table = "CN";
         my $card = 9E10;
         my ($cardEnabled, $card) = isCardTuningEnabled($fileContents, $table, $card);
         if($cardEnabled == 1) {
            print "   $table card adjustment applied (card = $card).\n";
         } elsif($cardEnabled == 0) {
            print "   ATTENTION: $table card adjustment not applied (card = $card).\n";
         }
      }
   } else {
      print "   WARNING: Unable to determine card adjustments as cardinalities.out was not provided.\n";
   }

   # check runstats
   print "\nDatabase statistics collection dates for key tables\n";
   if(-f "$dataDir/runstats_times.out") {
      my $fileContents = slurpFile("$dataDir/runstats_times.out");
      my @tablesToCheck = ("LDAP_ENTRY", "CN", "UID", "SN", "O", "OU", "PROCESS", "ACTIVITY");
      foreach my $table (sort @tablesToCheck) {
         my $lastRunstats = getLastRunstats($fileContents, $table);
         if($lastRunstats == -1) {
            print "   ATTENTION: Statistics have not been collected on table $table.\n";
         } elsif($lastRunstats > 0) {
            print "   statistics for table $table were last updated $lastRunstats\n";
         }
      }
   } else {
      print "   WARNING: Unable to determine card adjustments as runstats_times.out was not provided.\n";
   }

   # check bufferpools
   print "\nDatabase buffer pools\n";
   if(-f "$dataDir/bufferpools.out") {
      my $fileContents = slurpFile("$dataDir/bufferpools.out");
      my $buffPages = 0;
      my $sumTotalSize = 0;
      my @bpsToCheck = ("IBMDEFAULTBP","LDAPBP","ENROLEBP");

      # pull BUFFPAGE if any of the bufferpools use it
      if($fileContents =~ /-1/) {
         if(-f "$dataDir/db.cfg") {
            my $tempFileContents = slurpFile("$dataDir/db.cfg");
            if($tempFileContents =~ /\Q(BUFFPAGE)\E\s+=\s+(\d+)/) {
               $buffPages = $1;
            } else {
               print "   WARNING: Unable to determine BUFFPAGE size from db.cfg.\n";
            }
         } else {
            print "   WARNING: Unable to determine BUFFPAGE size as db.cfg was not provided.\n";
         }
      }

      foreach my $bp (sort @bpsToCheck) {
         # skip the bp if it doesn't exist
         next if($fileContents !~ /^$bp\s+([^\s]+)\s+(\d+)$/m);

         my ($npages, $pagesize) = ($1, $2);
         if($npages == -1) {
            print "   ATTENTION: bufferpool $bp is controlled by BUFFPAGE database config\n";
            if($buffPages == 0) {
               print "   WARNING: Unable to calculate bufferpool size for $bp due to unknown BUFFPAGE value.\n";
               next;
            }
         }

         $npages = $buffPages if($npages == -1);
         my $pagesizeKB = $pagesize/1024;
         my $totalSize = ($npages * $pagesizeKB) / 1024;
         $sumTotalSize += $totalSize;

         if($npages == -2) {
            print "   bufferpool $bp is managed by STMM\n";
         } else {
            print "   bufferpool $bp has $npages ${pagesizeKB}k pages totaling ${totalSize}m in size\n";
         }
      }

      print "   total bufferpool size: ${sumTotalSize}m\n";
   } else {
      print "   WARNING: Unable to evalute buffer pools as bufferpools.out was not provided.\n";
   }

   # check db2set
   print "\nDatabase environment (db2set)\n";
   if(-f "$dataDir/db2set.out" && -f "$dataDir/os.name" && -f "$dataDir/db2level.out") {
      my $db2Level = slurpFile("$dataDir/db2level.out");
      my $osName = slurpFile("$dataDir/os.name");
      my $fileContents = slurpFile("$dataDir/db2set.out");

      my $foundProblem = 0;

      if($osName=~/^AIX/) {
         if($fileContents =~ /EXTSHM/) {
            if($productUsingDB2 eq "ITDS") {
               print "   ATTENTION: DB2ENVLIST=EXTSHM should not be enabled for DB2 under ITDS.\n";
               $foundProblem = 1;
            } elsif($db2Level =~ /DB2 v9/) {
               print "   ATTENTION: DB2ENVLIST=EXTSHM should not be enabled for DB2 v9 on AIX when using the type-4 JDBC driver.\n";
               $foundProblem = 1;
            }
         } else {
            if($productUsingDB2 eq "ITIM" && $db2Level =~ /DB2 v8/) {
               print "   ATTENTION: DB2ENVLIST=EXTSHM should be enabled for DB2 v8 on AIX.\n";
               $foundProblem = 1;
            }
         }
      }

      if($productUsingDB2 eq "ITIM" && $fileContents!~/DB2_RR_TO_RS=YES/) {
         print "   ATTENTION: DB2_RR_TO_RS=YES should be set for DB2 under ITIM.\n";
         $foundProblem = 1;
      } elsif($productUsingDB2 eq "ITDS" && $fileContents=~/DB2_RR_TO_RS=YES/) {
         print "   ATTENTION: DB2_RR_TO_RS=YES should not be set for DB2 under ITDS.\n";
         $foundProblem = 1;
      }

      if(!$foundProblem) {
         print "   No problems found with environment settings\n";
      }
   } else {
      print "   WARNING: Unable to determine environment settings as either db2set.out, os.name, or db2level.out was not provided.\n";
   } 

   if($productUsingDB2) {
      print "\nAdditional information\n";
      print "   the product using DB2 appears to be: $productUsingDB2\n";
      if(@productsUsingITDS) {
         print "   the product(s) using ITDS appears to be: @productsUsingITDS\n";
      }
   }

   print "\nAdditional scripts to use\n";
   print "   The following performance scripts will yield useful information as well\n";
   print "   when run against the snapshot.out file included in the dataset:\n";
   print "      perfanalyze_database.pl -i $dataDir/snapshot.out\n";
   print "      perfanalyze_dynamicsql.pl -i $dataDir/snapshot.out\n";
   print "      perfanalyze_tablespaces.pl -i $dataDir/snapshot.out\n";
   if($productUsingDB2 eq "ITDS") {
      print "      perfanalyze_indexes.pl -i $dataDir/snapshot.out -d [schemaDir]\n";
      print "         where [schemaDir] is a directory containing the ITDS schema files\n";
   }

   if(-d $tempDir) {
      print "   HINT: Use the -k option with this script to retain the extracted data.\n";
   }
} elsif($dataType eq "tds") {
   # ITDS version
   print "\nITDS Version\n";
   if(-f "$dataDir/monitor.out") {
      my $fileContents = slurpFile("$dataDir/monitor.out");
      if($fileContents =~ /^version\W+(.*)$/im) {
         print "   version: $1\n";
      } else {
         print "   The monitor.out file does not contain version information.\n";
      }
   } else {
      print "   WARNING: unable to determine ITDS version as monitor.out was not provided.\n";
   }

   # check cache sizes
   print "\nCache sizes\n";
   if(-f "$dataDir/etc/ibmslapd.conf") {
      my $fileContents = slurpFile("$dataDir/etc/ibmslapd.conf");
      my %defaultCacheValues = ( "EntryCacheSize" => 25000, "ACLCacheSize" => 25000, "FilterCacheSize" => 25000 );
      my %desiredCacheValues = ( "ACLCacheSize" => 100, "FilterCacheSize" => 100 );
      foreach my $cache (sort keys %defaultCacheValues) {
         my $cacheValue = $defaultCacheValues{$cache};
         if($fileContents =~ /\Qibm-slapd$cache\E:\s+(\d+)/) {
            my $cacheCurrentValue = $1;
            print "   $cache = $cacheCurrentValue\n";
            if($cacheValue == $1) {
               print "   ATTENTION: ibm-slapd$cache is at the default value ($cache).\n";
               if($desiredCacheValues{$cache}) {
                  print "   ATTENTION: ibm-slapd$cache should be set to $desiredCacheValues{$cache} in an ITIM environment.\n";
               }
            }
         }
      }
   } else {
      print "   WARNING: Unable to evaluate cache sizes as etc/ibmslapd.conf was not provided.\n";
   }

   # auditing records
   print "\nAuditing\n";
   if(-f "$dataDir/monitor.out") {
      my $fileContents = slurpFile("$dataDir/monitor.out");
      if($fileContents =~ /^auditinfo\W+(.*)$/im) {
         # parse out the audit settings
         my %auditSettings;
         foreach my $auditSetting (split(", ", $1)) {
            my ($auditKey, $auditValue) = split(":", $auditSetting);
            $auditSettings{$auditKey}=$auditValue;
         }

         if($auditSettings{"ibm-audit"} eq "true") {
            print "   ATTENTION: auditing is enabled, this may be a performance hit\n";
            print "   the following are being audited:\n";
            foreach my $auditKey (sort keys %auditSettings) {
               print "      $auditKey\n"
                  if($auditSettings{$auditKey} eq "true" && $auditKey ne "ibm-audit");
            }
         } else {
            print "   auditing is not enabled\n";
         }
      } else {
         print "   The monitor.out file does not contain auditing information.\n";
      }
   }

   # tracing
   print "\nTracing\n";
   if(-f "$dataDir/monitor.out") {
      my $fileContents = slurpFile("$dataDir/monitor.out");
      if($fileContents =~ /^trace_enabled\W+(.*)$/im) {
         if($1 eq "TRUE") {
            print "   ATTENTION: tracing is enabled, this can be a major performance hit\n";
         } else {
            print "   tracing is disabled\n";
         }
      } else {
         print "   The monitor.out file does not contain tracing information.\n";
      }
   } else {
      print "   WARNING: unable to determine if tracing is enabled as monitor.out was not provided.\n";
   }

   print "\nThe following performance scripts will yield useful information as well\n";
   print "if you have an ITDS audit.log or a DB2 dynamic SQL snapshot:\n";
   print "   perfanalyze_audit.pl\n";
   print "   perfanalyze_indexes.pl\n";
} elsif($dataType eq "was") {
   # load Java settings
   print "Java settings:\n";
   my @javaPropertyFiles = findFiles($dataDir, "Java\/Properties");
   my $fileContents = slurpFile(pop @javaPropertyFiles);
   my @interestedProperties = ("java.vm.vendor", "java.version", "com.ibm.vm.bitmode", "os.arch", "java.runtime.version");
   foreach my $property(@interestedProperties) {
      if($fileContents=~/$property = (.*)/) {
         print "   $property = $1\n";
      }
   }
   print "\n";

   # get a list of all servers
   my @serverNames;
   my @serverFileList = findFiles($dataDir,".*?\/config\/cells\/.*?\/servers\/[^\/]+\$");
   foreach my $serverFile (@serverFileList) {
      push @serverNames, $1 if($serverFile=~/\/([^\/]+)$/);
   }

   # for each server, do some checks
   foreach my $serverName (sort @serverNames) {
      next if($serverName eq "nodeagent");

      print "Server: $serverName\n";

      # load JVM settings
      print "   JVM settings:\n";
      my @serverFiles = findFiles($dataDir, "\/config\/cells\/.*\/servers\/$serverName\/server.xml");
      # should be only one of these
      if(scalar(@serverFiles) != 1) {
         print "      WARNING: unable to determine JVM settings for this server.\n";
      } else {
         my $serverFile = pop @serverFiles;
         my $fileContents = slurpFile($serverFile);
         if($fileContents=~/(<jvmEntries .+)/) {
            my $line = $1;
            my @interestedAttributes = ("initialHeapSize", "maximumHeapSize", "verboseModeGarbageCollection", "genericJvmArguments");
            foreach my $attribute (@interestedAttributes) {
               if($line=~/$attribute="(.*?)"/) {
                  print "      $attribute = $1\n";
               }
            }
         } else {
            print "      WARNING: unable to locate JVM settings in the server.xml file.\n";
         }
      }

      # check PMI settings
      print "   PMI settings:\n";
      my @pmiFiles = findFiles($dataDir, "\/config\/cells\/.*\/servers\/$serverName\/pmi-config.xml");
      # should be only one of these
      if(scalar(@pmiFiles) != 1) {
         print "      WARNING: unable to determine PMI settings for this server.\n";
      } else {
         my $foundProblem = 0;
         my $pmiFile = pop @pmiFiles;
         my $fileContents = slurpFile($pmiFile);
         if($fileContents=~/com.ibm.ws.wswebcontainer.stats.webAppModuleStats.*enable="(.*?)"/) {
            my $enable = $1;
            # check for URIRequestCount
            if($enable=~/15/) {
               print "      ATTENTION: URIRequestCount is enabled. If this is an Application Server\n";
               print "               used for ITIM, this should be disabled.\n";
               $foundProblem = 1;
            }
            # check for URIServiceTime 
            if($enable=~/17/) {
               print "      ATTENTION: URIServiceName is enabled. If this is an Application Server\n";
               print "               used for ITIM, this should be disabled.\n";
               $foundProblem = 1;
            }

            if(!$foundProblem) {
               print "      No PMI problems found.\n";
            }
         } else {
            print "      Web Application PMI settings not found in file.\n";
         }

      }

      print "\n";
   }
}

# clean up the tempDir if it exists
if(-d $tempDir) {
   if($options{k}) {
      print "\nKeeping temporary data directory $dataDir...\n";
   } else {
      system("rm -r $tempDir");
   }
}

# vim: sw=3 ts=3 expandtab
