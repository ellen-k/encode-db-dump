#!/usr/bin/ruby

# Transforms the modencode chado database into a format useful for encode3.
# The input is a file structure where each 'modencode submission' is a directory,
# and the database tables relevant to that sub are tab-separated files within the directory.

# the output is tab separated files with headers that are items that exist inside the submissions.
# so to speak.


# Here are the input and output file names, in case they need to be changed.
  # Location of input files
  basedir = "encode3/dump-all/bad_tabs_only" #$ test set
  basedir = "encode3/dump-all/output"
  #basedir = "encode3/OLD/old_dump_all/final/data/"
  
  # Which of those files to use
  #subs = Dir.entries(basedir).reject{|s| s =~ /\./ }[0..50] # a small test
  subs = Dir.entries(basedir).reject{|s| s =~ /\./ }
#  subs = ["339"]

  # Main tab file output
  main_out = File.open("Bmt-output-allA.txt", "w")

  # Supplementary tab file outputs
  person_out = File.open("Bmt-output-personA.txt", "w") 

  # Temporary -- tab file for items with multiple values
  multi_headers = File.open("Bmt-output-multiheadersA.txt", "w")

  io = {
    :main_out,
      main_out,
    :multi_out,
      multi_headers,
    :person_out,
      person_out,
    :geo_out,
      File.open("Bmt-output-geoA.txt", "w")
     }


# special case has a lot of hardcoded logic here.
# It's about whether the headers need to be handled specifically
# eg geo / SRA ids.
# returns false if the header can be dealt with as normal.
  
  # Otherwise
def special_case(header, table, header_items, v_col, r_col)

  # Skip Anonymous data
  return {} if header =~ /^:Anonymous Datum #\d+$/
  

  # Set up the hash of info to return
  header_info = {
    :print_header, # What header to print it as
      header,
    :outfile,
      :multi_out, # what file to print it to
    :rank_group,
      nil, # What other items to group it with
    :values,
      header_items.map{|item| values_by_rank(item, v_col, r_col)}
    }
    

  # Person table
  # TODO re-include
  # I think i can just stick it on the multi- table for now
  #if table == "experiment_prop"
  #  if ( header =~ /^Person/ ) || ( ["Lab", "Project"].include? header ) then
  #    # header_info[:rank_group] = :person # TODO include this -- commented for testing
  #    header_info[:outfile] = :person_out
  #    return header_info
  #  end
  #end

  # GEO Records
  # TODO also do SRA records
  if table == "attribute"
    return {} if( header =~ /^GSM\d+:data_url$/ )# Just an URL to GEO, don't need

    if header =~ /^GSM\d+:GEO_record$/ then # The header is the geoid itself for some reason
      header_info[:outfile] = :geo_out
      header_info[:print_header] = "GEO_record"
      header_info[:values] = [header.sub(":GEO_record", "")]
      return header_info
    end
  end

  # TODO add more special cases
  false
end



### Helper functions ###

  # Takes data lines and the columns for value and rank
  # produces an array of the values, with array index = rank for that value
  def values_by_rank(lines, v_col, r_col)
    # TODO
    ["TODO"]
  end
  # constructs a string from the header_cols that represents a
  # header. h-cols in format "2,3" "3" or "1,2,5" eg.
  # and line is an array of strings.
  def get_header(line, header_cols)
    header_cols.to_s.split(",").map(&:to_i).map{|c| line[c]}.join(":")
  end

  # given a header constructed by get_header,
  # return the lines that have it (by reconstnucting it)
  def find_lines_by_header(data, header, hcols)
    data.select{|line| get_header(line, hcols) == header}  
  end


  # prints the items
  def print_rows(sub_id, data, h_col, value_col, rank_col, io_info) # need more inputs?
    # Get the headers
    headers = data.map{|d| get_header(d, h_col) }

    headers.uniq.each{|header| 
      header_items = find_lines_by_header(data, header, h_col)
      if header_items.empty? then
          puts "NO ITEM FOR HEADER #{header} in sub #{s}. THIS SHOULD NEVER HAPPEN."
          return
      end

      # Check if header is special
      if( sc_result = special_case(header, io_info[:table], header_items, value_col, rank_col); sc_result ) then

        # empty hash indicates 'print nothing' for this header
        next if sc_result.empty?
        # otherwise, use the passed hash to figure out
        # -- what to print
        # and what file to print it in

        # If there's no rank group, just put the values down
        if sc_result[:rank_group].nil? then
          sc_result[:values].each{|val|
            io_info[sc_result[:outfile]].puts [sub_id, sc_result[:print_header], val].join("\t")
          }
        else
          # There's a rank_group, so we need to match it with other things in that rank group 
          # TODO
        end
      else # No special case -- regular unique or non-unique item
        if header_items.length > 1 then
          header_items.each{|item|
            io_info[:multi_out].puts [sub_id, io_info[:table], header, item[value_col.to_i], item[rank_col.to_i]].join "\t" 
            # TODO -- note -- looks like we can't guarantee header + rank will be unique, which is bullshit
            # but not sure how we will deal with it. may be rare.
          }
        else
          # Header is unique -- write the line
          line = header_items.first
          io_info[:main_out].puts [sub_id, io_info[:table], header, line[value_col]].join("\t")
        end
      end
  }
  end

### Main Code ###

# Here are the tables we are getting info from
# The items are --- name of the table, columns to get key from,
# col to get rank from,
# cols to get val from, and # of tabs the line should have
main_tables = [
  ["attribute", "1,2", 3, 4, 7],
  ["data", "1,2", nil, 3,  6],
  ["experiment_prop", "2", 3, 4, 7] #,
  #["protocol", "1",2, 5]
  ]

# Protocol table :

  protocol = "protocol" # TODO : print out protocols 


# LIST OF BAD SUBS
badsubs = %w[
1043
3723
3721
1042
1041
1040
1044
448
3536
2929
515
3312
5530
5329
2720
34
445
5529
5328
214
340
215
2304
2718
2270
339
]


# For each submission, for each of the relevant tables,
# get headers & print info based on them. 
puts "starting"
subs.each{|s|
  print "#{s}."
  if badsubs.include? s
    print "--SKIPPED--"
    next
  end
  STDOUT.flush
  
  main_tables.each{|t|
    table_name = t[0]
    io[:table] = table_name
    header_cols = t[1]
    tabcount = t[4] # how many tabs should this table have
    current_table = File.join(basedir, s, table_name)
    dataf = File.open(current_table, "r") if File.exist? current_table
    data = dataf.readlines.map{|l| l.split("\t")} if File.exist? current_table
    dataf.close if File.exist? current_table
   
    rank_col = t[2]
    value_col = t[3]

    unless data.nil? then
      # Print the rows!
      print_rows(s, data, header_cols, value_col, rank_col, io) # TODO   
    end
  } 
}

# Close all open files. we assume that anything that can be queried about closing can be closed.
io.values.each{|file|
  file.close if file.respond_to?("closed?") && !(file.closed?)
}

