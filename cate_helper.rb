#!/usr/bin/env ruby

require 'open-uri'
require 'mechanize'
require 'date'
require 'nokogiri'
require 'io/console'
require 'optparse'

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# CATe uses the following URL format to dispense files:     
# https://cate.doc.ic.ac.uk/showfile.cgi?key=CATE_MAGIC_KEY  
#  
# where CATE_MAGIC_KEY == YEAR:CONST_ONE:FILE_NUMBER:CLASS:FILE_TYPE:USERNAME  
#  
# YEAR        is always 2014 (?)  
# CONST_ONE   is always 1    (?)  
# FILE_NUMBER is an integer associated with the file to download
# CLASS       is your class - one of c1, c2, c3, j1, j2, j3   
# FILE_TYPE   is one of NOTES, SPECS, DATA, MODELS  
# USERNAME    is your IC account username   
#  
# for instance connecting to:  
# https://cate.doc.ic.ac.uk/showfile.cgi?key=2014:1:44:c2:DATA:lmc13  
# will download:  
# Lab-2.tar.gz - the data file for the second lab assignment in C++ #44
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# This represents an Imperial College student
#
# :username => IC account username
# :password => IC account password     - needed for downloading files from CATe
# :year     => current year on CATe    - 2014 (?)
# :classes  => either Computing or JMC - one of c1, c2, c3, j1, j2, j3 
Student = Struct.new(:username, :password, :year, :classes)


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# This represents a module in Computing course
#
# :name      => name of the module as shown on CATe
# :noteNums  => array of FILE_NUMBER for the note files
# :exercises => array of Exercise structs for this module
_Module = Struct.new(:name, :noteNums, :noteURLs, :exercises, :piazza_exercises, :piazza_model_answers)


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# This represents an exercise or assigment 
#
# :name     => name of the exercise as shown on CATe
# :specsNum => FILE_NUMBER for the spec of this exercise
# :dataNum  => FILE_NUMBER for the data files of this exercise
# :modelNum => FILE_NUMBER for the model answers of this exercise
#
# dataNum and modelNum will be -1 if not provided for an exercise
Exercise = Struct.new(:name, :specsNum, :dataNum, :modelNum)


# Creates a directory in pwd if it doesn't already exist
def createDirectory(directoryName)
  Dir.mkdir(directoryName) unless File.exists?(directoryName)
end

# Downloads file from fileURL into targetDir. 
# Returns false iff file already existed and was not overwritten.
def downloadFileFromURL(targetDir, fileURL, student, override, fileInName)
  # puts targetDir + " " + fileURL + " " + username + " " + password + " "

  # Open file from web URL, using username and password provided
  # credentials = open("http://cate.doc.ic.ac.uk", :http_basic_authentication => [student.username, student.password])
  fileIn = open(fileURL, :http_basic_authentication => [student.username, student.password])
  if(fileInName == "")
    # Extract file name using this snippet found on SO
    begin 
      fileInName = fileIn.meta['content-disposition'].match(/filename=(\"?)(.+)\1/)[2]
    rescue Exception => e
      # puts "Unable to find file name" + e.message
      fileInName = File.basename(URI.parse(fileURL).path)
    end
  end
  # Calculate final path where file will be saved
  fileOutPath = targetDir + '/' + fileInName
  # If file already exists only override if true
  if (!override and File.exists?(fileOutPath)) 
    return false 
  end
    
  File.open(fileOutPath, 'wb') do |fileOut| 
    fileOut.write fileIn.read 
    return true
  end
end

def download_notes(agent, links, student)
  # exercises = $page.parser.xpath('//b//font//a[contains(text(), "View exercise specification")]').map{|link| link['href']}
  links.each do |link, exercises|
    notes_page = agent.get(link)
    module_name = notes_page.parser.xpath('//center//h3//b')
    module_name = module_name[module_name.size - 1].inner_html
    module_name_split = module_name.split(":")
    module_dir = "[" + module_name_split[0].strip + "] " + module_name_split[1].strip
    working_dir = Dir.pwd
    createDirectory(working_dir) 
    Dir.chdir(working_dir)
    createDirectory(module_dir)
    Dir.chdir(module_dir)
    print_equal
    puts "\nFetching the notes for #{module_dir}..."
    print_equal
    notes_dir = "Notes"
    createDirectory(notes_dir)
    notes = notes_page.parser.xpath('//a[contains(@href, "showfile.cgi?key")]|//a[contains(@title, "doc.ic.ac.uk")]|//a[contains(@title, "resources")]')
    notes.each do |note|
      if(note['href'] == '')
        note_url = open(note['title'], :http_basic_authentication => [student.username, student.password])
        ########################################################################
        ########################################################################
        ##########  If the url points to a pdf => download it ##################
        ##########       Else, redirect & parse for urls      ##################
        ########################################################################
        ########################################################################
        if(note_url.content_type == "application/pdf") 
          puts "Fetching #{note.text()}.pdf..."
          if(downloadFileFromURL(notes_dir, note['title'], student, false, note.text() + ".pdf"))
            puts "\t...Succes, saved as #{note.text()}.pdf"
          else 
            puts "\t...Skip, #{note.text()}.pdf already exists"
          end
        else
          # check for Dulay's Notes
          download_external_notes(notes_dir, note['title'], student)
        end
      else # Download local notes
        puts "Fetching #{note.text()}.pdf..."
        local_note = "https://cate.doc.ic.ac.uk/" + note['href']
        if(downloadFileFromURL(notes_dir, local_note, student, false, note.text() + ".pdf"))
          puts "\t...Succes, saved as #{note.text()}.pdf"
        else 
          puts "\t...Skip, #{note.text()}.pdf already exists"
        end
      end
    end
    Dir.chdir(working_dir)
  end
end # End download_notes(links)

def download_external_notes(notes_dir, link, student)
  agent = Mechanize.new
  agent.add_auth(link, student.username, student.password)
  external_page = agent.get(link)
  local_notes = external_page.parser.xpath('//a[contains(text(), "Slides")]|//a[@class="resource_title"]').map{ |link| link['href']  }
  local_notes.each do |local_note| 
    file_name = File.basename(URI.parse(local_note).path)
    puts "Fetching #{file_name}..."
    if(downloadFileFromURL(notes_dir, local_note, student, false, file_name))
      puts "\t...Succes, saved as #{file_name}.pdf"
    else 
      puts "\t...Skip, #{file_name}.pdf already exists"
    end
  end
end

def print_equal
  for i in 1..$cols
    print "="
  end
end # End print_equal

def download_exercises(agent, module_dir, exercise_row, student)
  createDirectory(module_dir)
  working_dir = Dir.pwd
  Dir.chdir(module_dir)
  exercise_row.each do |exercise| 
    createDirectory(exercise.text())
    exercise_link = "https://cate.doc.ic.ac.uk/" + exercise['href']
    puts "Fetching #{exercise.text()}.pdf..."
      if(downloadFileFromURL(exercise.text(), exercise_link, student, false, exercise.text() + ".pdf"))
        puts "\t...Succes, saved as #{exercise.text()}.pdf"
      else 
        puts "\t...Skip, #{exercise.text()}.pdf already exists"
      end
  end
  Dir.chdir(working_dir)
end # End download_exercises

def parse(args)
    $opts = []
    opt_parser = OptionParser.new do |opts|
      opts.banner = "Usage: example.rb [options] [path-optional]"
      opts.separator ""
      opts.separator "Specific options:"
      opts.on("-i", "--install", "Install Ruby RVM and dependencies") do |i|
        system("\\curl -sSL https://get.rvm.io | bash")
        system("gem install mechanize")
        system("gem install nokogiri")
      end
      opts.on_tail("-h", "--help", "Show this message") do
        $opts << "-h"
        puts opts
        exit
      end
    end
    opt_parser.parse!(args)
  end #End parse

begin
################################################################################
#########################          CATe Login        ###########################
################################################################################
  if(!ARGV.empty?)
    parse(ARGV)
  end
  print "IC username: "
  username = gets.chomp
  print "IC password: "
  system "stty -echo"
  password = gets.chomp
  system "stty echo"
  puts ""
  print "Class: " 
  classes = gets.chomp
  print "1 = Autumn\t2 = Christmas\t3 = Spring\t4 = Easter\t5 = Summer\nPeriod: "
  period = gets.chomp
  print "Academic year: "
  year = gets.chomp
  student = Student.new(username, password, year, classes)
  $rows, $cols = IO.console.winsize
  begin
    agent = Mechanize.new
    agent.add_auth('https://cate.doc.ic.ac.uk/' ,student.username, student.password, nil, "https://cate.doc.ic.ac.uk")
    $page = agent.get("https://cate.doc.ic.ac.uk")
    puts "\nLogin succesful, welcome back #{student.username}!\n"

    $page = agent.get("https://cate.doc.ic.ac.uk/timetable.cgi?period=#{period}&class=#{student.classes}&keyt=#{year}%3Anone%3Anone%3A#{student.username}")
    links = $page.parser.xpath('//a[contains(@href, "notes.cgi?key")]').map { |link| link['href'] }.compact.uniq

    ############################################################################
    #######################      Parse the table       #########################
    #######################     one row at a time      #########################
    #######################   get all exercise links   #########################
    #######################  for each row individually #########################
    ############################################################################
    rows = $page.parser.xpath('//tr[./td/a[contains(@title, "View exercise specification")]]')
    module_name = Nokogiri::HTML(rows[0].inner_html).xpath('//b[./font]').text()
    module_name_split = module_name.split("-")
    module_dir = "[" + module_name_split[0] + "] " + module_name_split[1]
    rows.each do |row|
      if(!Nokogiri::HTML(row.inner_html).xpath('//b[./font]').text().nil? && !Nokogiri::HTML(row.inner_html).xpath('//b[./font]').text().empty?)
        module_name = Nokogiri::HTML(row.inner_html).xpath('//b[./font]').text()
        module_name_split = module_name.split("-")        
        module_dir = "[" + module_name_split[0].strip + "] " + module_name_split[1].strip
        print_equal
        puts "\nFetching the exercises for #{module_dir}..."
        print_equal
      end
      exercises1 = Nokogiri::HTML(row.inner_html).xpath('//a[contains(@title, "View exercise specification")]')#.map{ |link| link['href']  }
      download_exercises(agent, module_dir, exercises1, student)
    end
    download_notes(agent, links, student)
  rescue Exception => e
    puts e.message
  end
  puts "\nAll done! =)"
rescue Exception => e
  puts "> Something went bad :(\n->" + e.message
end
