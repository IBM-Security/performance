#!/usr/bin/perl

use XML::DOM;
   
# perfanalyze_workflow.pl
# Author: Casey Peel (cpeel@us.ibm.com)
# Last Updated: 2007/10/05 1336 MDT
# Summary:
#    Displays ITIM workflows
# Description:
#    This takes either a file containing the workflow XML or 
#    information to pull the XML from the LDAP server (via -r and friends).
#
#    The script requires XML::DOM be installed.
#  
#    Reading an LDAP server is easiest but requires that the Net::LDAP perl
#    module be installed. If the module is not installed the script gives some hints
#    on how to install it.
#
#    Similarly, wanting to see the graph requires that Graph::Easy be installed.
#  

use Getopt::Std;

# Debug? 
$DEBUG=0;
   
getopts('r:u:p:b:f:ghaxi:o:') or usage();
usage() if($opt_h);

# Print Usage and exit
sub usage {
   print STDERR <<EOF
   
Usage: $0 [-a][-g] [-i inputFile | [-r host [-u username -p password] -b itimBase ][-f filter]] [-o outputFile]
LDAP options:
  -r - remote LDAP server to query
  -b - ITIM base (eg: ou=acme,dc=com)
  -u - username (if not specified, bind will be anonymous)
  -p - password
  -f - erGlobalID or workflow name to analyze
       (if blank, will list all workflows)

Output options:
  -g - print out an ASCII graph (requires Graph::Easy)
  -a - print out all possible workflow paths
  -x - print out the workflow XML

Other options:
  -i - file containing workflow for processing
  -o - file to put the processed results in, default is STDOUT

Note: use unix-style slashes for all files and directories, even if on Windows

EOF
;
exit;
}

# some basic error checking
if($opt_r && !$opt_b) {
   die("Error: You must specify the ITIM base using -b\n");
}

# without something else specified, enable the full path showing
# since that doesn't require module dependencies
if(!$opt_g && !$opt_a && !$opt_x) {
   $opt_a=1;
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

# Default output file is STDOUT
$outputFileHandle=*STDOUT;

# Unbuffer $outputFileHandle
select((select($outputFileHandle), $|=1)[0]);

# Open the file to put the output in, if necessary
if($opt_o) {
   open OUTPUT, ">$opt_o" || die("Unable to open $opt_o for writing\n");
   $outputFileHandle=*OUTPUT;
}

# parseWorkflowFile function
sub parseWorkflowFile {
   my ($filename) = @_;

   my $parser = XML::DOM::Parser->new();
   my $doc = $parser->parsefile($filename);

   return parseWorkflow($doc);
}

sub parseWorkflowString {
   my ($string) = @_;

   my $parser = XML::DOM::Parser->new();
   my $doc = $parser->parse($string);

   return parseWorkflow($doc);
}

sub parseWorkflow {
   my ($doc) = @_;

   my $rootNode=$doc->getDocumentElement();

   # get the activities
   foreach my $activityNode ($rootNode->getElementsByTagName("ACTIVITY",false)) {
      my $activityName = $activityNode->getAttributes()->getNamedItem("ACTIVITYID")->getValue();
      print "DEBUG: found activity $activityName\n" if($DEBUG);
      $activityHash{$activityName}=$activityNode;
   }

   # get the transitions
   foreach my $transNode ($rootNode->getElementsByTagName("TRANSITION",false)) {
      my $transNode = $transNode->getElementsByTagName("REGULAR",true)->item(0);
      my $from = $transNode->getAttributes()->getNamedItem("FROM")->getValue();
      my $to = $transNode->getAttributes()->getNamedItem("TO")->getValue();
      print "DEBUG: found transition $from -> $to\n" if($DEBUG);
      push @{$transHash{$from}}, $to;
   }
}


sub _showAllPaths {
   my ($from,$priorPath) = @_;

   if($from eq "END") {
      print "$priorPath\n";
      return;
   }

   foreach $to (@{$transHash{$from}}) {
      for(my $index=0;$index<$level;$index++) { print "   "; }
      $priorPath.=" --> $to";
      _showAllPaths($to,$priorPath);
   }
}

sub createGraph { 
   my($graph) = @_;

   foreach $from (keys %transHash) {
      foreach $to (@{$transHash{$from}}) {
         print "DEBUG: adding edge: $from -> $to\n" if($DEBUG);
         $graph->add_edge( $graph->add_node($from), $graph->add_node($to));
      }
   }

   return $graph;
}

# ----------------------------------------------------------

if($opt_i) {
   parseWorkflowFile($opt_i);
} elsif($opt_r) {
   print STDERR "fetching workflow from $opt_r, this may take a while....\n";
   $netLDAPAvail = eval { require Net::LDAP; 1; };

   # if the module isn't available, die
   if(!$netLDAPAvail) {
      print STDERR "\n";
      print STDERR "Net::LDAP module not installed, this module is required with the -r option.\n";
      print STDERR "With ActivePerl (ie: perl on Windows) you can use ppm to install it:\n";
      print STDERR "   Start -> Run -> 'ppm' or 'ppm3'\n";
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

   $ldap = Net::LDAP->new($opt_r);

   # if we can't connect, let the user know that
   die("ERROR: Unable to create LDAP connection to $opt_r\n") if(!$ldap);

   # if a user is specified, log in as them
   if($opt_u) {
      $result = $ldap->bind($opt_u, password => $opt_p);
   }
   # otherwise, bind anonymously
   else {
      $result = $ldap->bind;
   }

   # if the bind failed, print an error and die
   die("Error: " . $result->error() . "\n") if($result->is_error());

   # if a specific workflow name was given, use it
   if($opt_f) {
      $filter="(|(erglobalid=$opt_f)(erworkflowname=$opt_f))";
   }
   # otherwise, get a list of all workflows in the system
   else {
      $filter="objectclass=*";
   }

   $base="ou=operations,ou=itim,$opt_b";

   print "DEBUG: filter: $filter\n" if($DEBUG);

   # do the search
   $result = $ldap->search(base => "ou=operations,ou=itim,$opt_b",
                           scope => "one",
                           filter => $filter);

   # if the search failed, print an error and die
   if($result->is_error()) {
      print STDERR "Error: " . $result->error() . "\n";

      # do a one-level search and show the user all containers at that level
      # since they likely got the base wrong
      $result = $ldap->search(base => $opt_b,
                              scope => "one",
                              filter => "objectclass=*");
      print STDERR "Your itimBase (-b) may be incorrect. Here are the DNs under $opt_b:\n";
      foreach $entry ($result->entries) {
         print STDERR "   " . $entry->dn() . "\n";
      }
      print STDERR "Specify the entry with the ou=itim subcontainer\n";
      exit(1);
   }

   # process the results
   if(!$opt_f) {
      print "No filter was specified. The following workflows were retrieved from $opt_r:\n";
      printf "%-15s %-25s %-20s %-14s %s\n", "erCategory", "erProcessName", "erWorkflowName", "erLastModTime", "erGlobalID";
      foreach $entry ($result->entries) {
         $erCategory=$entry->get_value("erCategory");
         $erProcessName=$entry->get_value("erProcessName");
         $erWorkflowName=$entry->get_value("erWorkflowName");
         $erGlobalID=$entry->get_value("erglobalid");
         $erLastModifiedTime=$entry->get_value("erlastmodifiedtime");
         printf "%-15s %-25s %-20s %-14s %s\n", $erCategory, $erProcessName, $erWorkflowName, $erLastModifiedTime, $erGlobalID;
      }
      $ldap->unbind;
      exit;
   }
   # they've given us a filter value of some sort
   else {
      foreach $entry ($result->entries) {
         parseWorkflowString($entry->get_value("erXML"));

         # if they want the raw XML, lets print that out here
         if($opt_x) {
            print "Workflow XML:\n";
            print $entry->get_value("erXML");
            print "\n";
         }
      }
   }
   $ldap->unbind;
}

if($opt_a) {
   print "\n";
   print "All possible workflow paths:\n";
   _showAllPaths("START","START");
}

if($opt_g) {
   $graphEasyAvail = eval { require Graph::Easy; 1; };

   # if the module isn't available, die
   if(!$graphEasyAvail) {
      print STDERR "\n";
      print STDERR "Graph::Easy module not installed, this module is required with the -g option.\n";
      print STDERR "With ActivePerl (ie: perl on Windows) you can use ppm to install it:\n";
      print STDERR "   Start -> Run -> 'ppm' or 'ppm3'\n";
      print STDERR "   At the prompt, type: install perl-Graph-Easy\n";
      print STDERR "On Linux systems, try to install it via your package manager:\n";
      print STDERR "   On RHEL systems as root:\n";
      print STDERR "      yum install perl-Graph-Easy\n";
      print STDERR "On other Unix systems, use CPAN:\n";
      print STDERR "   perl -MCPAN -e shell\n";
      print STDERR "   At the prompt, type: install Graph::Easy\n";
      print STDERR "\n";
      exit(1);
   }

   print "\n";
   print "Graph of workflow:\n";
   print "Note: This could take a while, depending on the complexity of the graph.\n";
   $graph = createGraph(Graph::Easy->new());
   $graph->timeout(10);
   $graph->set_attribute("flow","south");

   print $graph->as_ascii();
}


# vim: sw=3 ts=3 expandtab
