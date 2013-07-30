#!/usr/bin/perl

# Adds a category ('type') column to the output of get-wiki-dbinfo.pl
# pulls information from the modencode wiki database

use DBI;
use LWP::Simple;
use strict;
use warnings;
use YAML;

# Constructs the output line for the item
sub makeline{
  my $rundbh = $_[0]; # The database handle to fetch output from
  my $subid = $_[1]; # Submission ID
  my $oldold = $_[2]; # Original oldid
  my $oldtitle = $_[3]; # Original title


  # IF there's no result at all, redisplay the old info
  my @res = $rundbh->fetchrow_array();
  if( !(@res) ){
    print OUTPUT "$subid\t$oldtitle\t$oldold\tNOT_IN_WIKI\tNOT_IN_WIKI\n";
    return ;
  }

  # Get the official title, latest revision, and first (if any) category 
  my ($ptitle, $category, $latestrev) = @res ;
  if( !(defined($category))){ 
    $category = "" ;
  }

  # Get remaining categories 
  while( my ($foo, $newcat, $bar) = $rundbh->fetchrow_array()){
    $category = "$category;$newcat" ;
  }

  print OUTPUT "$subid\t$ptitle\t$oldold\t$latestrev\t$category\n";
}

#### MAIN ####

#### Load Settings ####

unless( scalar(@ARGV) == 1){
  print "    Usage: perl categorize_wikipages.pl <configuration file>" .
      "\n    See SAMPLE.perl_conf.yml for a sample configuration.\n"; 
  exit;
}

my ($settings_file) = @ARGV;

unless (-e $settings_file){
  print "Can't find file $settings_file to load configuration!\n";
  exit;
}

my $SETTINGS = YAML::LoadFile($settings_file) or die "Couldn't load settings file $settings_file:$!";

my $inputlines = $SETTINGS->{'output_file'} ; # Takes outputfile from find_wikipage_references
open INPUT_LINES, $inputlines or die $!;

my $output_file = $SETTINGS->{'wiki_output_file'} ;
open OUTPUT, ">$output_file" or die "Can't open wiki_output_file $output_file  for writing: $!";


#### Connect to database and prepare statements ####

my $dbh_wiki = DBI->connect( $SETTINGS->{'wiki_db_handle'},
                        $SETTINGS->{'wiki_db_user'},
                        $SETTINGS->{'wiki_db_pw'}) or die "Can't connect to database " . $SETTINGS->{'wiki_db_handle'} .
                                                     " with wiki_db_user " . $SETTINGS->{'wiki_db_user'} .
                                                     " and your wiki_db_pw: $!\n";


my $find_by_title = $dbh_wiki->prepare("select page.page_title,
 categorylinks.cl_to, page.page_latest 
 from page
 left join categorylinks on categorylinks.cl_from = page.page_id 
 where page.page_title = ?");

my $find_by_oldid = $dbh_wiki->prepare("select page.page_title,categorylinks.cl_to, page.page_latest 
from revision 
join page on revision.rev_page = page.page_id 
left join categorylinks on categorylinks.cl_from = revision.rev_page 
where revision.rev_id = ?");

print OUTPUT "Subid\tTitle\tOldid\tLatest_Oldid\tTypes\n";
while (my $wikipage = <INPUT_LINES>) {

  # input format: 
  # subid, title, oldid, [old type], this last being pretty unhelpful

  chomp $wikipage;
  my ($subid, $title, $oldid, $oldtype) = split(/\t/, $wikipage);

  print "$subid." ;

  # If there's no OLDID, try looking for the title.
  if ($oldid eq "NO_OLDID") {

    # Hackily escape the title
    $title =~ s/ /_/g ;
    $title =~ s/%2B/+/g ;

    $find_by_title->execute($title);
    makeline($find_by_title, $subid, $oldid, $title);

  } else {
    # Great, we have an oldid, look it up
    $find_by_oldid->execute($oldid);
    makeline($find_by_oldid, $subid, $oldid, $title);
  }
}

END { # make sure to disconnect properly if it crashes (only if has already connected)
  print "\nGoodbye...\n";
  $dbh_wiki->disconnect() if(defined($dbh_wiki));
}

