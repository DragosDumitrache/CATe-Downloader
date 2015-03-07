#!/usr/bin/env ruby


begin 
  gem 'mechanize', ">=2.7"
rescue Gem::LoadError => e
  system("gem install mechanize")
  Gem.clear_paths
end
require 'open-uri'
require 'mechanize'
require 'nokogiri'
require 'io/console'
require 'zlib'
require 'optparse'
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# This represents an Imperial College $student
#
# :username => IC account username
# :password => IC account password     - needed for downloading files from CATe
# :year     => the year from which you want to retrieve files from    
# :classes  => either Computing or JMC - one of c1, c2, c3, j1, j2, j3 
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
$student = Struct.new(:username, :password, :classes, :period, :year)

$cate_website = "https://cate.doc.ic.ac.uk"
$notes_dir = "Notes"
# Creates a directory in pwd if it doesn't already exist
def create_directory(directory_name)
  Dir.mkdir(directory_name) unless File.exists?(directory_name)
end

# Downloads file from file_URL into target_dir. 
# Returns false iff file already existed and was not overwritten.
def download_file_from_URL(target_dir, file_URL, override, file_in_name)
  # Open file from web URL, using username and password provided
  working_dir = Dir.pwd
  Dir.chdir(target_dir)
  file_URL = file_URL.to_s.gsub(" ", '')
  begin
    file_in = open(file_URL, :http_basic_authentication => [$student.username, $student.password])
  rescue StandardError => e
    if(e.message == "404 Not Found")
      puts "404 Oh my! It appears the file has disappeared from the server..."
    else 
      puts e.message
    end
    return  false
  end
  if(file_in_name == "")
    # Extract file name using this snippet found on SO
    begin 
      file_in_name = file_in.meta['content-disposition'].match(/filename=(\"?)(.+)\1/)[2]
    rescue Exception => e
      # puts "Unable to find file name" + e.message
      file_in_name = File.basename(URI.parse(file_URL.to_s).path)
    end
  end
  puts "Fetching #{file_in_name}..."
  # If file already exists only override if true
  if (!override && File.exists?(file_in_name)) 
    Dir.chdir(working_dir)
    puts "\t...Skip, #{file_in_name} already exists"
    return false 
  end
  File.open(file_in_name, 'w') do |file_out| 
    file_out.write file_in.read
    print_loading
    puts "\n\t...Success, saved as #{file_in_name}"
    Dir.chdir(working_dir)
    return true
  end
end   # End of download_file_from_url

def download_notes(notes, module_dir, current_link)
  working_dir = Dir.pwd
  if(!working_dir.include?(module_dir))
    Dir.chdir(module_dir) 
  else
    module_dir = working_dir
  end
  create_directory($notes_dir)
  notes.each do |note|
    if(note['href'] != "")
      local_note = note['href']
    else
      local_note = note['title']
    end
    name = note.text()
    local_note = local_note.to_s.gsub(" ", '')
    if(URI(local_note).relative?)
     local_note = URI.join(current_link, local_note).to_s
    end
    local_note = URI.encode(local_note)
    begin
      note_url = open(URI.parse(local_note), :http_basic_authentication => [$student.username, $student.password])
      if(note_url.content_type == "application/pdf") 
        download_file_from_URL($notes_dir, URI.parse(local_note), false, "")
      end
      if(note_url.content_type == "text/html")
        parse_external_notes(local_note, module_dir)
      end
    rescue OpenURI::HTTPError => e
      if (e.message != "404 Not Found")
        puts e.message
      end
    end
  end
  Dir.chdir(working_dir)
end

def download_exercises(module_dir, exercise_row, given_files)
  working_dir = Dir.pwd
  create_directory(module_dir)
  Dir.chdir(module_dir)
  exercise_row.zip(given_files).each do |exercise, givens|
    if(URI(exercise['href']).relative?)
      exercise_link = URI.join($cate_website, exercise['href']).to_s
    end 
    name = exercise.text()
    if(File.extname(name) == ".mp4")
        next
    end
    create_directory(name)
    if(File.extname(name) == "")
      file_name = name + ".pdf" 
    end
    download_file_from_URL(name, exercise_link, false, file_name)
    download_givens(name, givens)
  end
  Dir.chdir(working_dir)
end # End download_exercises

def download_givens(tutorial_dir, givens)
  if(givens != nil)
    page = $agent.get($agent.page.uri + givens['href'])  
    models = page.parser.xpath('//a[contains(@href, "MODELS")]')
    models.each do |model| 
      if(File.extname(model.text()) != ".mp4")
        local_file = $agent.page.uri + model['href']
        download_file_from_URL(tutorial_dir, local_file, false, model.text())
      end
    end
    data = page.parser.xpath('//a[contains(@href, "DATA")]')
    data.each do |d| 
      if(File.extname(d.text()) != ".mp4")
        local_file = $agent.page.uri + d['href']
        download_file_from_URL(tutorial_dir, local_file, false, d.text())
      end
    end
  end
end

def parse_notes(links)
  links.each do |link|
    if(URI(link).relative?)
      link = URI.join($cate_website, link).to_s
    end
    notes_page = $agent.get(link)
    working_dir = Dir.pwd 
    module_name = notes_page.parser.xpath('//center//h3//b')
    module_name = module_name[module_name.size - 1].inner_html
    module_name_split = module_name.split(":")
    module_dir = "[" + module_name_split[0].strip + "] " + module_name_split[1].strip
    puts module_dir
    create_directory(module_dir)
    print_equal
    puts "\nFetching the notes for #{module_dir}..."
    print_equal
    local_notes = notes_page.parser.xpath('//a[contains(@href, "showfile.cgi?key")]')
    external_note_pages = notes_page.parser.xpath('//a[contains(@title, "doc.ic.ac.uk")]
                                                  |//a[contains(@title, "resources")]
                                                  |//a[contains(@title, "imperial.ac.uk")]')
    download_notes(local_notes, module_dir, $agent.page.uri)
    download_notes(external_note_pages, module_dir, $agent.page.uri)
  end
end # End parse_cate_notes(links)

def parse_external_notes(url, module_dir)
  if(URI.parse(url).path.include?("~nd"))
    parse_dulay_course(url, module_dir)
  end
  if(URI.parse(url).path.include?("~dfg"))
    parse_hardware_course(url, module_dir)  
  end
  if(URI.parse(url).path.include?("/211/"))
    parse_operating_systems(url, module_dir)
  end
  if(URI.parse(url).path.include?("/212/"))
    parse_networks(url, module_dir)
  end
end

def parse_dulay_course(link, module_dir)
  $agent.add_auth(link, $student.username, $student.password)
  external_page = $agent.get(link)
  local_notes = external_page.parser.xpath(%(//a[contains(text(), "Slides")]
                    | //a[@class="resource_title"]))
  download_notes(local_notes, module_dir, link)
end # end parse_dulay_course

def parse_hardware_course(link, module_dir)
  $agent.add_auth(link, $student.username, $student.password)
  external_page = $agent.get(link)
  local_notes = external_page.parser.xpath(%(//a[contains(text(), "Slides")]
                    | //a[contains(text(), "Handout")])).map{ |l| l['href']  }
  download_notes(local_notes, module_dir, link)
  list = external_page.parser.xpath('//li[contains(text(), "Tutorial")]')
  list.each do |list_elem|
    working_dir = Dir.pwd
    tutorial_dir = list_elem.text().split("(")
    tutorial_dir = tutorial_dir[0].gsub("\n", " ").gsub("  ", " ").strip
    create_directory(tutorial_dir)
    puts "Fetching #{tutorial_dir}..."
    tuts = Nokogiri::HTML(list_elem.inner_html).xpath('//a[contains(text(), "Question")]')
   #TODO Find a way to parse the solutions from in between comments "
    tuts.each do |tut|
      download_file_from_URL(tutorial_dir, tut['href'], false, "")
    end
  end
end # end parse_hardware_course

def parse_operating_systems(link, module_dir)
    page = $agent.get(link)
    tutorials = page.parser.xpath('//div[@class = "data-table"]//a[contains(@href, "tutorial")]')
    local_notes = page.parser.xpath('//div[@class = "data-table"]//a[contains(@href, ".pdf")]')
    solutions = page.parser.xpath('//a[contains(@title, "solution")]')
    local_notes = local_notes.to_a
    local_notes.delete_if { |note| tutorials.include?(note) || solutions.include?(note)}
    working_dir = Dir.pwd
    download_notes(local_notes, module_dir, link)
    
    create_directory("Tutorials")
    Dir.chdir("Tutorials")
    tutorials.each do |tut|
      if(tut.text() != nil && tut.text() == tut['title'])
        download_file_from_URL(Dir.pwd, tut['href'], false, tut['title'] + ".pdf")
      end
    end
    solutions.each do |sol|
      download_file_from_URL(Dir.pwd, sol['href'], false, "")
    end
end

def parse_networks(link, module_dir)
    page = $agent.get(link)
    tuts_sols = page.parser.xpath('//div[@class = "data-table"]//a[contains(@title, "Exercise")]
                                                              |//a[contains(text(), "Worksheet")]')
    local_notes = page.parser.xpath('//div[@class = "data-table"]//a[contains(@href, "slides")]
                                                                |//a[contains(text(), "Slides")]
                                                                |//a[contains(text(), "Handouts")]')
    local_notes = local_notes.to_a
    local_notes.delete_if { |note| tuts_sols.include?(note)}
    download_notes(local_notes, module_dir, link)
    working_dir = Dir.pwd
    create_directory("Tutorials")
    Dir.chdir("Tutorials")
    tuts_sols.each do |tut|
      download_file_from_URL(Dir.pwd, tut['href'], false, "")
    end
end

def parse_cate_exercises() 
  rows = $page.parser.xpath('//tr[./td/a[contains(@title, 
                              "View exercise specification")]]')
  rows.each do |row|
    if( !Nokogiri::HTML(row.inner_html).xpath('//b[./font]').text().empty?)
      module_name = Nokogiri::HTML(row.inner_html).xpath('//b[./font]').text()
      module_dir = module_name
      puts module_dir
      print_equal
      puts "\nFetching the exercises for #{module_dir}..."
      print_equal
    end
    if(module_dir != nil) 
      $saved_module = module_dir
    else
      module_dir = $saved_module
    end
    exercise_row = Nokogiri::HTML(row.inner_html).xpath('//a[contains(@title, "View exercise specification")]')
    givens = Nokogiri::HTML(row.inner_html).xpath('//a[contains(@href, "given")]')
    download_exercises(module_dir, exercise_row, givens)
  end
end # end parse_cate_exercises

def parse(args)
  $opts = []
  opts_parser = OptionParser.new do |opts|
    opts.banner = "Usage: example.rb [options] [optional-path]"
    opts.separator ""
    opts.separator "Specific options:"
    opts.on("-p", "--path", "Download all materials to path or PWD") do |opt|
      $opts << opt
      ARGV.delete(opt)
      if(ARGV.empty?)
        ARGV << Dir.pwd
      end
      if(Dir.exists?(ARGV.last))
        Dir.chdir(ARGV.last)
        ARGV.pop
      else
        create_directory(ARGV.last)
        Dir.chdir(ARGV.last)
        ARGV.pop
      end
    end
    opts.on_tail("-h", "--help", "Show this message") do |opt|
      $opts << opt
      ARGV.delete(opt)
      puts opts
      exit
    end
  end
  opts_parser.parse!(args)
end

def student_login()
################################################################################
#########################          CATe Login        ###########################
################################################################################
  print "IC username: "
  username = gets.chomp
  print "IC password: "
  system "stty -echo"
  password = gets.chomp
  system "stty echo"
  puts ""
  print "Class: " 
  classes = gets.chomp.downcase
  print "1 = Autumn\t2 = Christmas\t3 = Spring\t4 = Easter\t5 = Summer\nPeriod: "
  period = gets.chomp
  print "Academic year e.g 2014:\n"
  year = gets.chomp
  Date.strptime(year, "%Y").gregorian? rescue "Invalid year"
  $student = $student.new(username, password, classes, period, year)
end

def print_equal
  for i in 1..$cols
    print "="
  end
end # End print_equal

def print_loading
  print "["
  for i in 2..$cols-2
    sleep(1.0/60.0)
    print "#"
  end
  print "]"
end

begin
  parse(ARGV)
  create_directory("DoC Resources")
  Dir.chdir("DoC Resources")
  student_login()
  $rows, $cols = IO.console.winsize
  begin
    $agent = Mechanize.new
    $agent.add_auth('https://cate.doc.ic.ac.uk/' ,$student.username, 
                            $student.password, nil, "https://cate.doc.ic.ac.uk")
    $page = $agent.get("https://cate.doc.ic.ac.uk")
    puts "\nLogin Successful, welcome back #{$student.username}!\n"

    $page = $agent.
            get("#{$cate_website}/timetable.cgi?period=#{$student.period}" + 
                       "&class=#{$student.classes}&keyt=#{$student.year}%" + 
                       "3Anone%3Anone%3A#{$student.username}")
    links = $page.parser.xpath('//a[contains(@href, "notes.cgi?key")]').map { |link| link['href'] }.compact.uniq
    parse_notes(links)
    parse_cate_exercises()
  rescue Exception => e
    puts e.message
  end
  puts "\nAll done! =)"
rescue StandardError => e
  if(e.message != "exit")
    puts "> Something went bad :(\n->" + e.message
  end
end
