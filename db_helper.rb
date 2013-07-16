require 'fileutils'
require 'pp'
require 'rubygems'
require 'dbi'
require 'dbd/Pg'
require 'yaml'

# DbHelper - manages connections to the ModEncode chado database conveniently

# Change RAILS_ROOT as necessary for the location of your config files
RAILS_ROOT = "/var/www/submit" unless defined?(RAILS_ROOT)

module DbHelper
  # Get database info
  def database
    # TODO : make more portable
    if File.exists? "#{RAILS_ROOT}/config/idf2chadoxml_database.yml" then
      db_definition = open("#{RAILS_ROOT}/config/idf2chadoxml_database.yml") { |f| YAML.load(f.read)
      }
      dbinfo = Hash.new
      dbinfo[:dsn] = db_definition['ruby_dsn']
      dbinfo[:user] = db_definition['user']
      dbinfo[:password] = db_definition['password']
      return dbinfo
    else
      raise Exception.new("You need an idf2chadoxml_database.yml file in your config/ directory with at least a Ruby DBI dsn.")
    end
  end

  # Connect to database
  def open_handle
    dbinfo = database
    db = DBI.connect(dbinfo[:dsn], dbinfo[:user], dbinfo[:password])
    db.execute "BEGIN TRANSACTION"
    db
  end

  def close_handle(db)
    db.execute "ROLLBACK"
    db.disconnect
  end

  # Test for demonstrating connection to database
  def runIt
    puts "running it!"
    no_db_commits = false

    # Connect to database
    dbinfo = database
    db = DBI.connect(dbinfo[:dsn], dbinfo[:user], dbinfo[:password])
    db.execute("BEGIN TRANSACTION") if no_db_commits

    sth_last_data_id = db.prepare("SELECT last_value FROM generic_chado.data_data_id_seq")

    sth_last_data_id.execute unless no_db_commits
    last_id = sth_last_data_id.fetch_hash["last_value"] unless no_db_commits

    puts last_id.inspect

    db.execute("ROLLBACK") if no_db_commits
    db.disconnect

    puts "ran."
  end
end
