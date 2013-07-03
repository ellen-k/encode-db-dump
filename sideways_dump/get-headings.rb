#!/usr/bin/ruby

# get the headings that we will make the giant graph out of
# Note that this code handles files which have inappropriate embedded tabs and newlines
# newly dumped files will no long have these problems.

# for each submission
# for each of the listed tables
# grab the appropriate columns

# Arguments
if ARGV.length < 2 then
  puts "Usage: ./get_headings.rb input_directory output_file [-f]
        -f: Fix embedded newlines or tabs." 
  exit
end

basedir = ARGV[0]
output_file = ARGV[1]
FIXTABS = ! ARGV[2].nil? # so technically it doesn't HAVE to be -f.

# table filename and the columns in it that we want
tables = [
  ["attribute", "1,2", 7],
  ["data", "1,2", 6],
  ["experiment_prop", "2", 7],
  ["protocol", "1", 5]
  ]

#subs = Dir.entries(basedir).reject{|s| s =~ /\./ }[0..50] # a small test
subs = Dir.entries(basedir).reject{|s| s =~ /\./ }

rawout = File.open(output_file, "w")

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
      #rawout.puts "#{s}-#{tfile}-#{heads.join("\n")}"
      rawout.puts heads.join("\n")
    end
  } 
}

rawout.close



