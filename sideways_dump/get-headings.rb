#!/usr/bin/ruby
require File.join(File.dirname(__FILE__), 'table_helper')

# get the headings that we will make the giant graph out of


# INPUTS
# Directory where submission tablespaces have been dumped to with dump_from_db.rb
# basename for output lists
# use -f to handle files with inappropriate newlines / tabs
# which newly dumped file will not have.

# OUTPUTS
# basename.raw
#   The raw headings, sorted by submission.
# basename.uniq
#   All headings which only appear once in every submission they appear in.
# basename.multi
#   All headings which appear at least twice in at least one submission
# basename.special
#   Special-cased headings -- see self.special() in table_helper.rb
#   which require special handling. Mostly GEO ids.
  

# Methods #

# Does this header match 'special case' criteria
# & thus should be excluded from the main tables ?
# When building regexes, remember that header will also include the tablename.
def special_case_this_header?(header)
  TableHelper.special(header).nil? ? false : true
end

# Main #
if ARGV.length < 2 then
  puts "Usage: ./get_headings.rb input_directory output_file_basename [-f]
        -f: Fix embedded newlines or tabs." 
  exit
end

basedir = ARGV[0]
baseout = ARGV[1]
FIXTABS = ! ARGV[2].nil? # so technically it doesn't HAVE to be -f.

# table filename, header column indices, and expected # of columns
tables = [
  ["attribute", "1,2", 7],
  ["data", "1,2", 6],
  ["experiment_prop", "2", 7] #,
#  ["protocol", "1", 5]       Don't include protocols; they'll be handled separately
  ]

puts "Fixing embedded newlines and tabs." if FIXTABS

subs = Dir.entries(basedir).reject{|s| s =~ /\./ }

fnames = Hash.new{|h, filetype| "#{baseout}.#{filetype}" } 

rawout = File.open(fnames["raw"], "w")
multiout = File.open(fnames["multi"], "w")
uniqout = File.open(fnames["uniq"], "w")
specialout = File.open(fnames["special"], "w")

subs.each{|sub|
  rawout.flush
  multiout.flush
  uniqout.flush
  specialout.flush
  print "#{sub}."
  STDOUT.flush

  tables.each{|table|
    tfile = table[0]
    cols = table[1]
    tabcount = table[2] # how many columns should this table have
    openme = File.join(basedir, sub, tfile)
    data = File.open(openme, "r").readlines.map{|l| l.split("\t")} if File.exist? openme


    rawout.puts "---#{sub}:#{tfile}---"
    
    # for each data line, get the header combo that it contains
    unless data.nil? then
      # hacky hack
      # because the old tabfiles didnt ACTUALLY clear tabs / newlines like they were supposed to
      # if a line doesnt have the right amount of tabs, join lines together until it does
      fixed = []
      if FIXTABS then
        current = [""]
        gtfo = false
        data.each{|line|

          if (line.length == tabcount) && current == [""]
            fixed << line
          else
            puts "Wrong # of columns found in #{sub}/#{tfile}." # alert
            # IMPORTANT join the items that has the evil embedded newline
            current[-1] += line.shift unless line.empty?
            # then join it
            current += line
            if current.length > tabcount then
              puts "Can't fix #{sub}/#{tfile}; skipping!" 
              # ABORT and drop the table's headings rather than make wrong ones 
              gtfo = true
              break
            end
            if current.length >= tabcount
              fixed << current
              current = [""]
            end
          end
        }
        next if gtfo # jump to next table

      else # not fixing tabs ; just copy it over.
        fixed = data
      end
      # from the data array,
      # pull out the values in the columns corresponding to cols
      # and join them with a :
      heads = fixed.map{|line|
        cols.split(",").map(&:to_i).map{|c| line[c]}.join(":")
      }

      # Note which file the headers are in, so that we can correlate the multiheaders later
      heads.map!{|head| "#{head}::#{tfile}" }

      # Log the raw headers
      rawout.puts heads.join("\n")

      # Clear out 'special' headers before checking for uniqueness, because
      # it's n^2 and makes a few subs run super slow.
      (specialheaders, normalheaders) = heads.partition{|s| special_case_this_header?(s)}
      specialout.puts specialheaders.uniq.join("\n")

      # Then, check for uniqueness: Are there any nonunique key:heading pairs?
      # If so, put them for the multiheading table.
      nonuniq,unique = normalheaders.uniq.partition{|h| normalheaders.count(h) > 1 }
      multiout.puts nonuniq.join("\n")
      uniqout.puts unique.join("\n")
    end
  } 
}

rawout.close
multiout.close
uniqout.close

puts "\nFinished processing input...cleaning up lists."

# Then, some file cleanup:
# Uniquify multiheaders, remove all headers appearing in 
# multiheaders from singleheaders, and resave.

multiheaders = File.open(fnames["multi"], "r").readlines.map{|s| s.chomp}.uniq
uniqheaders = File.open(fnames["uniq"], "r").readlines.map{|s| s.chomp}.uniq

uniqheaders.reject!{|s| multiheaders.include? s}
File.open(fnames["uniq"], "w").puts uniqheaders.join("\n")
File.open(fnames["multi"], "w").puts multiheaders.join("\n")
