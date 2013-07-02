require 'pp'
require File.join(File.dirname(__FILE__), 'db_helper')

# Format Helper --
# useful methods for helping to pull info from the modencode
# database. Formerly EDG (encode_data_getter).

# dependencies : released_projs method requires
# the modencode pipeline Rails' context.

include DbHelper

# Current version breaks colleage.rb
module FormatHelper
  
  module_function # All functions are callable as, eg, FormatHelper.exists

  def exists(item)
    return false if item.nil?
    return false if item.empty?
    true
  end

  def load_marshal(file)
    Marshal.load(File.open(file, "r"))
  end

  def save_marshal(array, file)
    f = File.open(file, "w")
    f.puts Marshal.dump(array)
    f.close
  end

  # Returns an array of released project ids 
  # if since_time, only returns ones modified since then.
  def released_projs(include_dep_sup = false, since_time = false)
    projs = Project.find_all_by_status(Project::Status::RELEASED).select{|p|
        # if include is false, then they must not be deprecated or superseded
        (include_dep_sup) || (! ( p.deprecated? || p.superseded?))
    }
    projs.reject!{|p| p.updated_at < since_time } if since_time
    projs.map!{|s| s.id.to_i}
    projs.sort!
  end

  # pass it an array of Project ids to go through
  # For each of them that exists in the DB, it runs the block
  # the caller provides and sticks the result onto an accumulator.
  def run_on_projects(projs)
    dbh = open_handle
    result = []
   
    projs.each{|sub|
      # Only try for subs in chado
      searchpath = "modencode_experiment_#{sub}_data" 
      path_exists = dbh.select_one "SELECT EXISTS ( SELECT * FROM pg_catalog.pg_namespace
          WHERE nspname = '#{searchpath}')"
      unless path_exists[0] then
        puts "\n#{sub} NOT IN DATABASE; SKIPPING"
        next
      end
      dbh.execute "SET search_path = '#{searchpath}'"

      result += yield(dbh, sub) # Pass the dbh to a block so it can do its thing
      # also provide sub id
      # it will return the array of the results
    }
    close_handle(dbh)
    result
  end
end
