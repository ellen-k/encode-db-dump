#!/usr/bin/perl

# Connects to the modencode submission database
# Scrapes all mention of wikipages and their flavor 

# This is a descendant of yostinso's update_whitelist.pl
# (found in repo modencode-wiki/whitelist_update/ )
# by way of my auto_update_whitelist.pl in that same repo.

use DBI;
use LWP::Simple;
use strict;
use warnings;
use YAML;
use URI::Escape qw();
use List::MoreUtils qw(first_index);
use feature qw(switch);

unless( scalar(@ARGV) == 1){
  print "    Usage: perl find_wikipage_references.pl <configuration file>" .
      "\n    See SAMPLE.perl_conf.yml for a sample configuration.\n"; 
  exit;
}

##### Load settings #####

my ($settings_file) = @ARGV;
my $SETTINGS = YAML::LoadFile($settings_file) or die "Couldn't load settings file $settings_file:$!";

my $projects_file = $SETTINGS->{'project_list'} ;
open PROJECTLIST, $projects_file or die "Can't get project_list $projects_file: $!";

# What column of projectlist should we use for PID and 'released' notation?
my $pid_col = $SETTINGS->{'input_pid_column'}; 
if (!defined $pid_col){ die "You must specify an input_pid_column in the settings file!" ;}

my $filter_by_released = $SETTINGS->{'filter_by_released'}; 
my $released_col = 0 ;

# don't filter by default
if (defined($filter_by_released) && ($filter_by_released  eq 'true')) {
  print "Checking only released submissions.\n";
  $filter_by_released = 1;
  $released_col = $SETTINGS->{'input_released_column'};
  if (!defined $released_col){
    die( "If filter_by_released is true in the settings file,\n" .
         "you must include an input_released_column value.");
  }
} else {
  $filter_by_released = 0;
}

my $output_file = $SETTINGS->{'output_file'} ;
open OUTPUT, ">$output_file" or die "Can't open output_file $output_file  for writing: $!";

print OUTPUT "SubmissionID\tTitle\tOldID\n"; 

print "Opened list of projects $projects_file and output file $output_file.\n";


#### Connect to database and prepare statements ####

my $dbh = DBI->connect( $SETTINGS->{'db_handle'},
                        $SETTINGS->{'db_user'},
                        $SETTINGS->{'db_pw'}) or die "Can't connect to database " . $SETTINGS->{'db_handle'} .
                                                     " with db_user " . $SETTINGS->{'db_user'} . 
                                                     " and your db_pw: $!\n";

print "Connected to database!\n";

# set up sth for getting search path & accessions from that project
my $sth_find_sp = $dbh->prepare("SELECT exists(SELECT schema_name 
                                 FROM information_schema.schemata 
                                 WHERE schema_name = ?)") or die $dbh->errstr;
my $sth_search_path = $dbh->prepare('SET search_path=?') or die "Couldn't prepare searchpath: " . $dbh->errstr;

# Get all mentions of wikipages (by db description)
# and get the mentions of each wiki dbxref in attribute, cvterm, data, experiment, & protocol tables.
my $sth_accession = $dbh->prepare("SELECT dbxref.accession, dbxref.dbxref_id,
                                   count(a.dbxref_id),
                                   count(c.dbxref_id),
                                   count(d.dbxref_id),
                                   count(e.dbxref_id),
                                   count(p.dbxref_id)
                                   FROM dbxref 
                                   INNER JOIN db ON dbxref.db_id = db.db_id
                                   LEFT JOIN attribute a on a.dbxref_id = dbxref.dbxref_id
                                   LEFT JOIN cvterm c on c.dbxref_id = dbxref.dbxref_id
                                   LEFT JOIN data d on d.dbxref_id = dbxref.dbxref_id
                                   LEFT JOIN experiment_prop e on e.dbxref_id = dbxref.dbxref_id
                                   LEFT JOIN protocol p ON p.dbxref_id = dbxref.dbxref_id
                                   WHERE db.description = 'URL_mediawiki_expansion'
                                   GROUP BY dbxref.accession, dbxref.dbxref_id
                                   HAVING dbxref.accession != '__ignore'"
                                 ) or die "Couldn't prepare accession: " . $dbh->errstr;


my $sp_exists = 0; # does the schema exists?
print "Getting list of accessions:\n";
$|=1; # please flush buffer.

#### Loop through submissions and get wikilinks for each ####

my @projitems; # row of submission list
my $pid; # submission id
my $released; # is this submission released
my $accession_type; # what kind of link is this

# For each released submission, get the accessions mentioned in dbxref
while (my $projline = <PROJECTLIST>) {
  @projitems = split("\t", $projline );
  $pid = $projitems[$pid_col];
  chomp($pid);

  # skip non-released subs if appropriate
  if ($filter_by_released) {
    $released = $projitems[$released_col];
    defined($released) or die "No release status info found in column " .
      "$released_col of input file! If you're not filtering by released,\n" .
      "please set the field to false in the configuration file." ;
    next if (!($released eq "released")) ;
  }

  print "Processing submission $pid...\n";

  # Get accession information from the database
  my $search_path = "modencode_experiment_$pid" . "_data" ;
  $sth_find_sp->execute($search_path) or die $dbh->errstr;
 
  # Make sure it's loaded
  ($sp_exists) = $sth_find_sp->fetchrow_array();
   if (! $sp_exists) { print "Submission #$pid not loaded; skipping.\n";  next ; } # project is probably not loaded.

  $sth_search_path->execute($search_path)  or die $dbh->errstr;
  $sth_accession->execute() or die "Couldn't execute accessions: " . $dbh->errstr;


  # Note: when I attempted to execute an SQL query INSIDE this while loop, it ran properly
  # for the first search_path and none of the subsequent ones. It is unclear what DBI's 
  # intended behavior is for reusing prepared statements while the search_path changes.
  while(my ($accession, $dbxref_id, @wikitype) = $sth_accession->fetchrow_array()) {
    # Clean the URL
    $accession =~ s|^\Qhttp://wiki.modencode.org/project/index.php?title=\E||g;
   
    # Split off the oldid if it has one
    $accession = URI::Escape::uri_unescape($accession);
    my ($title, $oldid) = split("&oldid=", $accession);

    # Special Case:
    # If the title is just a number, it's Celniker RNA
    if ( $title =~ /^\d+$/) {
      $title = "Celniker/RNA:$title";
    }

    # Special case: Some of the titles don't have &oldid
    # at the end, but just 'oldid'. Get rid of that.
    if ( $title =~ /oldid/) {
      my ($title, $oldid) = split("oldid=", $accession);
    }

    # Figure out what other tables reference this accession
    my $found_wikitype = "NO_WIKITYPE";
    given(first_index{ $_ > 0 } @wikitype  ) {
      when (0) {  $found_wikitype = "attribute"; }
      when (1) {  $found_wikitype = "cvterm"; }
      when (2) {  $found_wikitype = "data"; }
      when (3) {  $found_wikitype = "experiment_prop"; }
      when (4) {  $found_wikitype = "protocol"; }
      default  { print "\nCouldn't find type for $pid : $dbxref_id !\n"; }
    }

    # Print submission id, title, oldid, wikitype to OUTPUT
    print OUTPUT $pid . "\t" . $title . "\t";
    if (defined $oldid) {
      print OUTPUT $oldid . "\t";
    } else {
      print OUTPUT "NO_OLDID\t";
    }
    print OUTPUT $found_wikitype . "\n";
  }
}

END { # make sure to disconnect properly if it crashes (only if has already connected)
  print " Goodbye...\n";
  $dbh->disconnect() if(defined($dbh));
  close OUTPUT ;
}
