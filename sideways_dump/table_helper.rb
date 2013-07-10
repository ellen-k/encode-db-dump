

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

  # Is this a special header
  def self.special(header)

  end

  # Does this line have a special header
  def special(line)
    h = header(line)
    TableHelper.special(h)
    # TODO - return the appropriate value given a special header
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

