#!/usr/bin/ruby
# Given a list of mediawiki oldids and an output folder
# fetch the pages from the wiki
# uses wkhtmltopdf
# to be run on windows
# or wherever there is wkhtml to pdf


# USAGE
# In order to allow this to run on both windows and mac, 
# we will use a config file
# Pass on cmdline a text file containing the line in order:
# (may contain comments -any line containing a # will be ignored)
 
# full url to mediawiki index.php page
# full path to oldid list 
# full path to output folder
# full path to cookie jar
# full path to the wkhtmltopdf executable
# wiki username
# wiki password
# ec escape character for the shell escaping of '?' -- windows uses ^, others use \

# TODO : add column for which is the oldid
# and backup column if that doesnt work
# to allow input from the other output script

if ARGV.length != 1 then
  puts "Usage: ./fetch_pdf.rb <configuration file name>"
  exit
end

setup = File.open(ARGV[0], "r").readlines.map{|s| s.chomp}.reject{|s| ((s =~ /#/) || s.empty? )}
(
base_url,
oldid_list,
output_folder,
cookie_jar,
run_path,
name,
password,
ec) = setup

oldids = File.open(oldid_list, "r").readlines.map{|s| s.chomp} # just crashes if no file
Dir.mkdir output_folder unless File.directory? output_folder

# Setup:
# Use wget to make a cookie_jar.
# Then open it and attach the cookies independently to the run_cmd.
# (Using the cookie-jar directly just makes wkhtml delete it for some reason ?? )

setup_cmd = "wget --save-cookies #{cookie_jar} --keep-session-cookies --post-data " +
  "'wpName=#{name}&wpPassword=#{password}&wpLoginattempt=Log+in' " +
  "#{base_url}?title=Special:UserLogin#{ec}&action=submitlogin#{ec}" +
  "&type=login -O #{File.join(output_folder, "deleteme.html")} 2>/dev/null"

# run the setup command to get the cookies in the jar
`#{setup_cmd}`
puts setup_cmd

# Get the cookies back out of the jar
cookies = File.open(cookie_jar, "r").readlines.reject{|s|
  (s =~ /^\s*$/) || (s=~ /^\s*#/)}.map{|l|
  l.chomp.split("\t")[5..6]}
puts cookies.map{|s| "nam #{s[0]} val #{s[1]}"}
use_cookies = cookies.map{|s| "--cookie \"#{s[0]}\" \"#{s[1]}\""}.join(" ")

# then make the pdf for each protocol run
oldids.each{|oldid|
  puts "-------------#{oldid}--------------"
  run_cmd = "#{run_path} #{use_cookies} #{base_url}?oldid=#{oldid} " +
    " #{File.join(output_folder, oldid)}.pdf 2>/dev/null"
  `#{run_cmd}`
  puts run_cmd
}

puts "DONE"
