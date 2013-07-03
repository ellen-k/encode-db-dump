#!/usr/bin/ruby

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
#   Special-cased headings -- see special_case_this_header
#   Which require special handling. Mostly GEO ids.

# Arguments
if ARGV.length < 2 then
  puts "Usage: ./get_headings.rb input_directory output_file_basename [-f]
        -f: Fix embedded newlines or tabs." 
  exit
end

basedir = ARGV[0]
baseout = ARGV[1]
FIXTABS = ! ARGV[2].nil? # so technically it doesn't HAVE to be -f.


# Does this header match 'special case' criteria
# & thus should be excluded from the main tables
def special_case_this_header?(header)

  return true if( header =~ /^:Anonymous Datum #\d+$/)
  return true if( header =~ /^GSM\d+:data_url$/ )# Just an URL to GEO, don't need
  return true if( header =~ /^SRR\d+:data_url$/ )# Specific SRR ID
  return true if( header =~ /^GSM\d+:GEO_record$/) # Geo ID
  return true if( header =~ /^GEO:TMPID:.*$/) # Geo ID

  # TODO more cases

  return false
end



# table filename and the columns in it that we want
tables = [
  ["attribute", "1,2", 7],
  ["data", "1,2", 6],
  ["experiment_prop", "2", 7],
  ["protocol", "1", 5]
  ]

#subs = Dir.entries(basedir).reject{|s| s =~ /\./ }[0..50] # a small test
subs = Dir.entries(basedir).reject{|s| s =~ /\./ }

fnames = Hash.new{|h, filetype| "#{baseout}.#{filetype}" } 


rawout = File.open(fnames["raw"], "w")
multiout = File.open(fnames["multi"], "w")
singleout = File.open(fnames["uniq"], "w")

subs.each{|s|
  tables.each{|t|
    tfile = t[0]
    cols = t[1]
    tabcount = t[2] # how many columns should this table have
    openme = File.join(basedir, s, tfile)
    data = File.open(openme, "r").readlines.map{|l| l.split("\t")} if File.exist? openme


    rawout.puts "---#{s}:#{tfile}---"
    
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
            puts "Wrong # of columns found in #{s}/#{tfile}." # alert
            # IMPORTANT join the items that has the evil embedded newline
            current[-1] += line.shift unless line.empty?
            # then join it
            current += line
            if current.length > tabcount then
              puts "Can't fix #{s}/#{tfile}; skipping!" 
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

      # Check for uniqueness: Are there any nonunique key:heading pairs?
      # If so, put them for the multiheading table.
    
      nonuniq,unique = heads.uniq.partition{|h| heads.count(h) > 1 }
      multiout.puts nonuniq.join("\n")
      singleout.puts unique.join("\n")

      rawout.puts heads.join("\n")
    end
  } 
}

rawout.close
multiout.close
singleout.close

puts "Finished processing input...cleaning up lists."

# Then, some file cleanup:
# Remove all headers appearing in multiheaders from singleheaders

multiheaders = File.open(fnames["multi"], "r").readlines.map{|s| s.chomp}.uniq
singleheaders = File.open(fnames["uniq"], "r").readlines.map{|s| s.chomp}.uniq

singleheaders.reject!{|s| multiheaders.include? s}

# Then, separate out known special-case headers 

specialheaders, singleheaders = singleheaders.partition{|s| special_case_this_header?(s) }

# Write stuff to file

File.open(fnames["multi"], "w").puts multiheaders.join("\n")
File.open(fnames["uniq"], "w").puts singleheaders.join("\n")
File.open(fnames["special"], "w").puts specialheaders.join("\n")

