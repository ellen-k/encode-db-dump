#!/usr/bin/ruby
require File.join(File.dirname(__FILE__), 'table_helper')

# Transforms the modencode chado database into a format useful for encode3.

# Input:
  # Location of output directory from dump_from_db.rb
  # base path for outputs from get-headings.rb

# Output
  # Tab separarated charts with headings providing info from the submissions

unless ARGV.length == 3 then
  puts "Usage: ./make_table.rb db_dump_directory heading_basepath output_dirname"
  exit
end

basedir = ARGV[0]
heading_basepath = ARGV[1]
outdir = ARGV[2]

start_time = Time.now

# Input : submissions are dirs with fully numeric names
subs = Dir.entries(basedir).select{|s| s =~ /\A\d+\z/ }

# Output
Dir.mkdir outdir
io = {
  :uniq_out,
    File.open(File.join(outdir, "main-table.tsv"), "w"),
  :multi_out,
    File.open(File.join(outdir, "multi-headers.tsv"), "w"),
  :special_out,
    File.open(File.join(outdir, "special-headers.tsv"), "w"),
  :uniq_in,
    File.open([heading_basepath, "uniq"].join("."), "r").readlines.map{|l| l.chomp},
  :multi_in,
    File.open([heading_basepath, "multi"].join("."), "r").readlines.map{|l| l.chomp},
  :special_in, 
    TableHelper.special_headers_list
   }

tables = TableHelper.tables

# Add a submission id header for each table
SUBMISSION_ID_HEADER = "Submission_id"
[:uniq_in, :special_in, :multi_in].each{|input|
  io[input] << SUBMISSION_ID_HEADER
}


# Print output headers
io[:uniq_out].puts io[:uniq_in].join("\t")
io[:special_out].puts io[:special_in].join("\t")
io[:multi_out].puts io[:multi_in].join("\t")


puts "Processing submissions..."
subs.each{|sub|
  print "#{sub}."
  STDOUT.flush

  # Set up the line in each file for this submission.
  # Keys = the headers, values = the values
  uniq_values = {}
  # Values = array of value in rank order
  multi_values = Hash.new{|h, k| h[k] = []}
  # Values = array of values
  special_values = Hash.new{|h, k| h[k] = []}

  # And add the submission ID header for each
  uniq_values[SUBMISSION_ID_HEADER] = sub
  [multi_values, special_values].each{|outtable|
    outtable[SUBMISSION_ID_HEADER] << sub  
  }


  # Get the lines in each table and sort them into output tables
  tables.each{|tablekey, table|
    current_table = File.join(basedir, sub, table.name)
    unless File.exist? current_table then
      print "x"
      next
    end

    data = File.open(current_table, "r") 
    
    data.each_line{|line|
        
      header = table.header(line)
      value = table.value(line)

      # If it's a 'special' header (eg GEO id), store it hashed by
      # the output file's genericized special header.
      special_res = table.special(line)
      if !(special_res.nil?) then
        special_values[special_res[0]] << special_res[1]
        next
      end

      # If it's a uniq header, add the line's value to the uniq hash
      if io[:uniq_in].include? header then
        uniq_values[header] = value
        next
      end

      # If it's a multi header, add the line's value to multi hash,
      # arranging by rank (if available)
      if io[:multi_in].include? header then
        rank = table.rank(line)
        # if no rank, just stick it on
        if rank.nil? then
          multi_values[header] << value
          next
        end
        # There is a rank; check for collisions
        if multi_values[header][rank].nil? then
          multi_values[header][rank] = value
          next
        else # Collision in rank ; this happens frequently in the attribute table
          # Stick it in the same index, joined by a --
          multi_values[header][rank] += "--" + value
        end
        next
      end
      # Whoops, didn't recognize a header. This should never happen; complain
      puts "Found unrecognized header #{header} for #{sub}:#{table.name}!!!!"
    } 

    data.close if data.respond_to?("closed?") && !(data.closed?)
  } 
  # We've seen all the tables for the sub -- write it out!

  # uniq
  output_uniq = io[:uniq_in].map{|heading|
    uniq_values[heading].to_s
  }.join("\t")
  io[:uniq_out].puts output_uniq

  
  # Join values in rank order
  # Don't uniquify
  output_multi = io[:multi_in].map{|heading|
    multi_values[heading].join(";")
  }.join("\t")
  io[:multi_out].puts output_multi

  # special
  output_special = io[:special_in].map{|heading|
    special_values[heading].uniq.join(";")
  }.join("\t")
  io[:special_out].puts output_special

}

# Close all output files
io.values.each{|file|
  file.close if file.respond_to?("closed?") && !(file.closed?)
}

elapsed = Time.now - start_time
puts "\nDone! Processed #{subs.length} submissions in #{elapsed} seconds."

