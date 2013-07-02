#!/usr/bin/ruby

require File.join( File.dirname(__FILE__), '..', 'format_helper.rb'); 

# From the modencode database,
# for each submission in the following list 'projs':

#projs = FormatHelper.released_projs()
#projs = File.open("real-bad-tabs-to-do.txt", "r").readlines.map{|s| s.to_i}
projs = [3575, 666]

# dump the tables listed below into a tabular format,
# stripping tabs and newlines.

# Creates a directory for each submission in the specified output directory,
# with a file for each table.
output_basedir = "dbdump_output"

# Dependencies: Must be run in the rails context
# if we use the FormatHelper.released_projs() method

# Getting headers only: Run with --headers 
# to get a list of column headers instead of data
headers_only = false
if ARGV[0] == '--headers' then
  projs = [3575] # a random submission
  headers_only = true
  puts "Getting column headers only. See 'headers' dir inside #{output_basedir}."
end

# Aside: Getting all nonempty tables:
# They are just manually listed in a variable 'tables'
# but could also be determined using the following:

# SELECT relname FROM pg_class JOIN pg_namespace 
# ON (pg_class.relnamespace = pg_namespace.oid) WHERE relpages > 0 
# AND pg_namespace.nspname = 'public';

# select *, oid from pg_namespace limit 5 ;
# select relname, relnamespace from pg_class limit 5 ;

# where relnamespace is the same as oid
# so we can get the tables that are nonempty.

tables = "analysis
applied_protocol
attribute
cvterm
cv
data
db
dbxref
experiment_prop
experiment
organism
protocol
analysisprop
applied_protocol_data
experiment_applied_protocol
attribute_organism
data_attribute
protocol_attribute
cvterm_dbxref
cvterm_relationship
cvtermpath
cvtermprop
cvtermsynonym
data_attribute
data_organism
data_wiggle_data
organism_dbxref
organismprop".split "\n"


puts "Dumping submissions..." unless headers_only

# give run_on_projs a list, and it will provide a dbh
# and invoke the block on each sub in the list
# The block must return an array that will be added to the final array 
# returned by run_on_projects
subs = FormatHelper.run_on_projects(projs){|dbh, sub|
  print "#{sub}..." unless headers_only
  STDOUT.flush
  outd = File.join(output_basedir, (headers_only ? "headers" : sub.to_s)) 
  Dir.mkdir outd
  tables.each{|t|
    dbh_getinfo = "SELECT * from #{t}"
    if headers_only then
      dbh_getinfo = "SELECT column_name FROM information_schema.columns
      WHERE table_schema = 'modencode_experiment_#{sub}_data' and table_name = '#{t}'"
    end
    res = dbh.select_all dbh_getinfo
    # For each row item, remove all its internal tabs/ newlines, then join
    # rows with tabs.
    res.map!{|row| row.map{|item| item.to_s.gsub(/\s+/, " ")}.join("\t")}
    rr = res.join "\n"
    unless rr.empty? then
        ff = File.open(outd + "/#{t}", "w")
        ff.puts rr
        ff.close
    end
  }
  [sub]
}

puts subs.join " " unless headers_only
puts "Done."
