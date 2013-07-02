#!/usr/bin/ruby

# get the headings that we will make the giant graph out of
# Note that this code handles files which have inappropriate embedded tabs and newlines
# newly dumped files will no long have these problems.

# for each submission

# for each of the following tables

# grab the appropriate columns

# table filename and the columns in it that we want
tables = [
  ["attribute", "1,2", 7],
  ["data", "1,2", 6],
  ["experiment_prop", "2", 7],
  ["protocol", "1", 5]
  ]

basedir = "~/encode3/old_dump_all/final/data"
#subs = Dir.entries(basedir).reject{|s| s =~ /\./ }[0..50] # a small test
subs = Dir.entries(basedir).reject{|s| s =~ /\./ }

rawout = File.open("raw_output", "w")

subs.each{|s|
  tables.each{|t|
    tfile = t[0]
    cols = t[1]
    tabcount = t[2] # how many tabs should this table have
    openme = File.join(basedir, s, tfile)
    data = File.open(openme, "r").readlines.map{|l| l.split("\t")} if File.exist? openme
    
    # for each data line, get the header combo that it contains
    unless data.nil? then
    
    # hacky hack
    # because the old tabfiles didnt ACTUALLY clear tabs / newlines like they were supposed to
    # if a line doesnt have the right amount of tabs, join lines together until it does
      fixed = []
      current = [""]
      gtfo = false
      data.each{|line|
        if (line.length == tabcount) && current.empty?
          fixed << line
        else
          # IMPORTANT join the items that has the evil embedded newline
          current[-1] += line.shift unless line.empty?
          # then join it
          current += line
          if current.length > tabcount then
            puts "BAD LINE:#{s}#{tfile}" 
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



