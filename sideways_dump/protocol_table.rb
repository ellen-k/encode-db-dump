#!/usr/bin/ruby

# protocol_table.rb

# Creates a table of the protocols used in each modEncode submission and their types
# must be run after make_table.rb to get the listing of protocol headers

# Input:
  # Location of output directory from dump_from_db.rb
  # Location of output directory from make_table.rb

# Output
# Tab-separated table, with the protocol types as columns, and each modEncode
# submission as a row. The items in each column are the protocol names which
# have the specified type within each submission.

PROTOCOL_TYPE_HEADER = ":Protocol Type::attribute"

unless ARGV.length == 2 then
  puts "Usage: ./protocol_table.rb db_dump_directory output_dirname"
  exit
end

basedir = ARGV[0]
outdir = ARGV[1]

start_time = Time.now


# Input : submissions are dirs with fully numeric names
subs = Dir.entries(basedir).select{|s| s =~ /\A\d+\z/ }

# Output file
io = {
  :protocol_out,
    File.open(File.join(outdir, "protocol-table.tsv"), "w")
    }


# Find the input column for protocol types, fetch the types
multi_table_file = File.open(File.join(outdir, "multi-headers.tsv"), "r")
protocol_type_index = multi_table_file.readline.split("\t").index(PROTOCOL_TYPE_HEADER)
if protocol_type_index.nil? then
  puts "ERROR: Can't find the protocol type header '#{PROTOCOL_TYPE_HEADER} " + 
  "in multi-headers.tsv;\ndon't know where to get the list of protocol types from!"
  exit
end

# The protocol type column has prots separated with '--' or ';' - Example: 
# PCR;analysis_protocol--harvest--labeling;purify  
# So we need to split it up and uniq them.
io[:protocol_in] = multi_table_file.readlines.map{|line| 
  line.split("\t")[protocol_type_index].split(/(?:;|--)/) 
  }.flatten.uniq

# Add a submission id header for each table
SUBMISSION_ID_HEADER = "Submission_id"
io[:protocol_in] << SUBMISSION_ID_HEADER

# Print output headers
io[:protocol_out].puts io[:protocol_in].join("\t")

puts "Processing submissions..."
subs.each{|sub|
  print "#{sub}."
  STDOUT.flush

  # Set up the output line for this submission
  # Keys = header protocol types; values = list of protocols w/ that header
  protocol_table = Hash.new{|h, k| h[k] = []}

  # And add the submission ID header
  protocol_table[SUBMISSION_ID_HEADER] << sub  

  # Open the protocol table, get names and protocol IDs
  protfname = File.join(basedir, sub, "protocol")
  unless File.exists? protfname then
    print "[No protocol file, skipping]"
    next
  end

  protf = File.open(protfname, "r")
  my_prots = {} # Keys = protocol_id, values = a hash with :name and :types

  protf.each_line{|line|
  # Items: protocol_id name description dbxref_id version
    items = line.chomp.split "\t"
     my_prots[items[0]] = {:name => items[1]} 
     my_prots[items[0]][:types] = []
  }
  protf.close

  # Get the protocol type associated with each attribute with type Protocol Type
  attfname = File.join(basedir, sub, "attribute")
  unless File.exists? attfname then
    print "[No attribute file, skipping]"
    next
  end
  attf = File.open(attfname, "r")

  my_attrs = {} # key: attribute_id ; value: protocol type
  attf.each_line{|line|
    items = line.chomp.split "\t"
    my_attrs[items[0]] = items[4] if items[2] == "Protocol Type"
  }

  # Use protocol_attribute to link my_attrs and my_prots
  pattfname = File.join(basedir, sub, "protocol_attribute")
  unless File.exists? pattfname then
    print "[No protocol-attribute file, skipping]" 
    next
  end
  pattf = File.open(pattfname, "r")
  
  pattf.each_line{|line|
    # items : protocol_attribute_id protocol_id attribute_id
    items = line.chomp.split( "\t")
    found_type =  my_attrs[items[2]]
    # Add the type of the attribute to the 'type' array of the correct protocol 
    my_prots[items[1]][:types] << found_type unless found_type.nil? 
  }

  # Then, populate the table
  my_prots.each{|key, prot| 
    prot[:types] = [ "" ] if prot[:types].empty? # Give it the empty type if none found 
    prot[:types].each{|prot_type|
      if io[:protocol_in].include? prot_type then
          protocol_table[prot_type] << prot[:name]
      else
        # Whoops, didn't recognize a header. This should never happen; complain
        puts "Found unrecognized protocol type #{prot_type} for #{sub}!"
      end
    }
  } 

  # Construct the line and print it
  output_line = io[:protocol_in].map{|heading|
    protocol_table[heading].join(";")
  }.join("\t")
  io[:protocol_out].puts output_line

}

# Close all output files
io.values.each{|file|
  file.close if file.respond_to?("closed?") && !(file.closed?)
}

elapsed = Time.now - start_time
puts "\nDone! Processed #{subs.length} submissions in #{elapsed} seconds."

