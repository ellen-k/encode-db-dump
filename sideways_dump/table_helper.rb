

# table_helper.rb
# Shared data and methods for get_headings and make_table
# usage: require 'table_helper'


class TableHelper

  # name - filename of the table
  # header_cols - array of colum indicies to be joined by : to make the header
  # value - column idx for the value
  # rank - column idx for the rank
  # num_cols - how many columns should there be? 
  def initialize(name, header_cols, value_col, rank_col, num_cols)
    @name = name
    @header_cols = header_cols
    @value_col = value_col
    @rank_col = rank_col
    @num_cols = num_cols
  end

  attr_reader :name

  def split_line(line)
    l = ((line.class == String)? line.split("\t") : line )
    throw "Bad # of fields! Expecting #{@num_cols}, got #{l.length}!" unless l.length == @num_cols
    l
  end

  ## Useful methods ##

  def header(line)
    l = split_line(line)
    @header_cols.map{|c| l[c]}.join(":") + "::" + @name
  end

  def value(line)
    l = split_line(line)
    l[@value_col] 
  end

  # Determine if a header needs to be given special treatment.
  # The keys in this hash are regexes which match the targeted headers.
  # The values are arrays; value[0] is the header in the special table
  # that the matching item will have.
  # value[1] is the value in the special table.
  # If it is based on the 'value' from the original table, it is a
  # regex with a cature group which provides the desired output.
  # If it is based on the passed heading, it is a Proc that can be
  # run on the heading to produce the desired output. It's hilarious.
  # see self.special for example usage.
  INFO_SPECIAL_TABLE =
    { 
        /:Anonymous (?:Extra )?Datum #\d+/, # Anonymous Data
        ["Anonymous Data", /(.*)/],

        /^GS[EM]\d+:data_url/, # GEO ID 
        ["GEO ids", Proc.new {|h| /^(GS[EM]\d+)/.match(h)[1]}],

        /^SR[ARX].*:data_url/,  #SRR, SRA, SRX IDs
        ["SRA ids", Proc.new {|h| /^(SR[ARX].*):data_url/.match(h)[1]}],

        /^SRR\d+:ShortReadArchive_project_ID/,  #SRR ID
        ["SRA ids", /(.*)/],

        /^GSM\d+:GEO_record/, # Geo ID
        ["GEO ids", /(.*)/],

        /^GEO:TMPID:.*:(?:GEO_record|data_url)/, # Temp Geo ID
        ["temp GEO ids", Proc.new {|h| /^(GEO:TMPID:.*):(?:GEO_record|data_url)/.match(h)[1]}],

        /^SRA:TMPID:.*(?:ShortRead|data_url)/, # Temp SRA ID
        ["temp SRA ids", Proc.new{|h| /^(SRA:TMPID:.*):(?:ShortRead|data_url)/.match(h)[1]}],

        /modENCODE Reference for/, # Reference to sub
        ["modENCODE Reference", /(.*)/]
  }

  # All possible special headers for the OUTPUT 'special' file 
  def self.special_headers_list
    INFO_SPECIAL_TABLE.values.map{|v| v[0]}.uniq
  end 
 
  # Checks if the header requires special treatment
  # will return either nil (if it doesn't), or
  # a pair of new header name and (value OR regex to get value) 
  def self.special(header)
    result = nil
    INFO_SPECIAL_TABLE.each{|key, value|
      if header =~ key then
        if value[1].class == Proc then
          result = [value[0], value[1].call(header)]
        else
          result = [value[0], value[1]]
        end        
        break
      end
    }
    result
  end

  # Does this line have a special header?
  # If, so, return the new header & value
  def special(line)
    h = header(line)
    ret = TableHelper.special(h)
    # If ret[1] is a regex, apply it to the value field
    # of the line; that is the result.
    if (! ret.nil?) && (ret[1].class == Regexp) then
      match = ret[1].match(value(line))
      ret[1] = (match.nil? ? nil : match[1])
    end
    ret
  end

  # Tables!  
  def self.tables
    {
     "attribute", TableHelper.new("attribute", [1,2], 4, 3, 7),
     "data", TableHelper.new("data", [1,2], 3, nil, 6),
     "experiment_prop",  TableHelper.new("experiment_prop", [2], 4, 3, 7)
    }
  end
end

