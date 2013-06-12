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

# Get the cookie jar set up

setup_cmd = "#{run_path} --post wpName #{name} --post wpPassword #{password} --post wpLoginattempt Log+in " +
            "--cookie-jar #{cookie_jar} #{base_url}?title=Special:UserLogin" +
            "#{ec}&action=submitlogin#{ec}&type=login#{ec}&returnto=Main_Page #{File.join(output_folder, "deleteme.pdf")}"


# run the setup command to get the cookies in the jar
`#{setup_cmd}`
puts setup_cmd

# then make the pdf for each protocol run
oldids.each{|oldid|
  puts "-------------#{oldid}--------------"
  run_cmd = "#{run_path} --cookie-jar #{cookie_jar} #{base_url}?oldid=#{oldid} #{File.join(output_folder, oldid)}.pdf"
  `#{run_cmd}`
}

puts "DONE"
