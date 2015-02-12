#!/usr/bin/env ruby

require 'open-uri'
require 'mechanize'
require 'nokogiri'
require 'io/console'
require 'zlib'
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# This represents an Imperial College $student
#
# :username => IC account username
# :password => IC account password     - needed for downloading files from CATe
# :year     => the year from which you want to retrieve files from    
# :classes  => either Computing or JMC - one of c1, c2, c3, j1, j2, j3 
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
$student = Struct.new(:username, :password, :classes, :period, :year)

# Creates a directory in pwd if it doesn't already exist
def create_directory(directory_name)
  Dir.mkdir(directory_name) unless File.exists?(directory_name)
end

# Downloads file from fileURL into targetDir. 
# Returns false iff file already existed and was not overwritten.
def download_file_from_URL(target_dir, file_URL, override, file_in_name)
  # Open file from web URL, using username and password provided
  # credentials = open("http://cate.doc.ic.ac.uk", :http_basic_authentication => [$student.username, $student.password])
  file_in = open(file_URL, :http_basic_authentication => [$student.username, $student.password])
  if(file_in_name == "")
    # Extract file name using this snippet found on SO
    begin 
      file_in_name = file_in.meta['content-disposition'].match(/filename=(\"?)(.+)\1/)[2]
    rescue Exception => e
      # puts "Unable to find file name" + e.message
      file_in_name = File.basename(URI.parse(file_URL).path)
    end
  end
  # Calculate final path where file will be saved
  file_out_path = target_dir + '/' + file_in_name
  # If file already exists only override if true
  if (!override && File.exists?(file_out_path)) 
        return false 
  end
  File.open(file_out_path, 'wb') do |file_out| 
    file_out.write file_in.read 
    return true
  end
end   # End of download_file_from_url

def parse_cate_notes(links)
  links.each do |link|
    if(URI(link).relative?)
      link = URI.join("https://cate.doc.ic.ac.uk", link).to_s
    end
    notes_page = $agent.get(link)
    working_dir = Dir.pwd 
    module_name = notes_page.parser.xpath('//center//h3//b')
    module_name = module_name[module_name.size - 1].inner_html
    module_name_split = module_name.split(":")
    module_dir = "[" + module_name_split[0].strip + "] " + module_name_split[1].strip
    create_directory(module_dir)
    Dir.chdir(module_dir)
    print_equal
    puts "\nFetching the notes for #{module_dir}..."
    print_equal
    notes_dir = "Notes"
    create_directory(notes_dir)
    notes = notes_page.parser.xpath('//a[contains(@href, "showfile.cgi?key")]|//a[contains(@title, "doc.ic.ac.uk")]|//a[contains(@title, "resources")]')
    notes.each do |note|
      if(note['href'] == '')
        note_url = open(note['title'], :http_basic_authentication => [$student.username, $student.password])
        if(note_url.content_type == "application/pdf") 
          puts "Fetching #{note.text()}.pdf..."
          if(download_file_from_URL(notes_dir, note['title'], false, note.text() + ".pdf"))
            print_loading
            puts "\n\t...Success, saved as #{note.text()}.pdf"
          else 
            puts "\t...Skip, #{note.text()}.pdf already exists"
          end
        else
          if(note_url.content_type == "application/mp4")

          else 
            # check for External Notes
            if(URI.parse(note['title']).path.include?("~nd"))
              parse_dulay_course(notes_dir, note['title'], module_dir)
            end
            if(URI.parse(note['title']).path.include?("~dfg"))
              parse_hardware_course(notes_dir, note['title'], module_dir)  
            end
          end
        end
      else # Download local notes
        name = note.text()
        if(File.extname(name) == "")
          name = name + ".pdf" 
        end
        puts "Fetching #{name}..."
        local_note = $agent.page.uri + note['href']
        if(download_file_from_URL(notes_dir, local_note, false, name))
          print_loading
          puts "\n\t...Success, saved as #{name}"
        else 
          puts "\t...Skip, #{name} already exists"
        end
      end
    end
    Dir.chdir(working_dir)
  end
end # End parse_cate_notes(links)


def parse_dulay_course(notes_dir, link, module_dir)
  $agent.add_auth(link, $student.username, $student.password)
  external_page = $agent.get(link)
  local_notes = external_page.parser.xpath(%(//a[contains(text(), "Slides")]
                    | //a[@class="resource_title"])).map{ |link| link['href']  }
  download_external_files(notes_dir, local_notes, module_dir, link)
end # end parse_dulay_course

def parse_hardware_course(notes_dir, link, module_dir)
  $agent.add_auth(link, $student.username, $student.password)
  external_page = $agent.get(link)
  local_notes = external_page.parser.xpath(%(//a[contains(text(), "Slides")]
                    | //a[contains(text(), "Handout")])).map{ |l| l['href']  }
  download_external_files(notes_dir, local_notes, module_dir, link)
  list = external_page.parser.xpath('//li[contains(text(), "Tutorial")]')
  list.each do |list_elem|
    working_dir = Dir.pwd
    tutorial_dir = list_elem.text().split("(")
    tutorial_dir = tutorial_dir[0].gsub("\n", " ").gsub("  ", " ").strip
    create_directory(tutorial_dir)
    puts "Fetching #{tutorial_dir}..."
    tuts = Nokogiri::HTML(list_elem.inner_html).xpath('//a[contains(text(), "Question")]')
   
    tuts.each do |tut|
      if(download_file_from_URL(tutorial_dir, tut['href'], false, "Question Sheet.pdf"))
        print_loading
        puts "\n\t...Success, saved as Question Sheet.pdf"
      else 
        puts "\t...Skip, Question Sheet.pdf already exists"
      end
    end
  end
  
end # end parse_hardware_course

def download_external_files(notes_dir, local_notes, module_dir, link)
  local_notes.each do |local_note| 
    file_name = File.basename(URI.parse(local_note).path)
    if(URI(local_note).relative?)
      local_note = URI.join(link, local_note).to_s
    end
    if(File.extname(file_name) == "")
        file_name = file_name + ".pdf" 
    end
    puts "Fetching #{file_name}..."
    if(download_file_from_URL(notes_dir, local_note, false, file_name))
      print_loading
      puts "\n\t...Success, saved as #{file_name}"
    else 
      puts "\t...Skip, #{file_name} already exists"
    end
  end
  
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

def parse_cate_exercises() 
  rows = $page.parser.xpath('//tr[./td/a[contains(@title, 
                              "View exercise specification")]]')
  rows.each do |row|
    if( !Nokogiri::HTML(row.inner_html).xpath('//b[./font]').text().empty?)
      module_name = Nokogiri::HTML(row.inner_html).xpath('//b[./font]').text()
      module_name_split = module_name.split("-")        
      module_dir = "[" + module_name_split[0].strip + "] " + module_name_split[1].strip
      print_equal
      puts "\nFetching the exercises for #{module_dir}..."
      print_equal
    end
    if(module_dir != nil) 
      $saved_module = module_dir
    else
      module_dir = $saved_module
    end
    exercises1 = Nokogiri::HTML(row.inner_html).xpath('//a[contains(@title, "View exercise specification")]')
    givens = Nokogiri::HTML(row.inner_html).xpath('//a[contains(@href, "given")]')
    download_exercises(module_dir, exercises1, givens)
  end
end # end parse_cate_exercises

def download_exercises(module_dir, exercise_row, given_files)
  working_dir = Dir.pwd
  create_directory(module_dir)
  Dir.chdir(module_dir)
  exercise_row.zip(given_files).each do |exercise, givens|
    if(URI(exercise['href']).relative?)
      link = URI.join("https://cate.doc.ic.ac.uk", exercise['href']).to_s
    end 
    exercise_link = link
    name = exercise.text()
    if(File.extname(name) == ".mp4")
        next
    end
    create_directory(name)    
    puts "Fetching #{name}..."
    if(File.extname(name) == "")
      file_name = name + ".pdf" 
    end
    if(download_file_from_URL(name, exercise_link, false, file_name))
      print_loading
      puts "\n\t...Success, saved as #{file_name}"
    else 
      puts "\t...Skip, #{file_name} already exists"
    end
    
    if(givens != nil)
      page = $agent.get($agent.page.uri + givens['href'])  
      models = page.parser.xpath('//a[contains(@href, "MODELS")]')
      models.each do |model| 
        if(File.extname(model.text()) == ".mp4")
          next
        end
        puts "Fetching #{model.text()}..."
        local_file = "https://cate.doc.ic.ac.uk/" + model['href']
        if(download_file_from_URL(name, local_file, false, model.text()))
          print_loading
          puts "\n\t...Success, saved as #{model.text()}"
        else 
          puts "\t...Skip, #{model.text()} already exists"
        end     
      end
      data = page.parser.xpath('//a[contains(@href, "DATA")]')
      data.each do |d| 
        if(File.extname(d.text()) == ".mp4")
          next
        end
        puts "Fetching #{d.text()}..."
        local_file = "https://cate.doc.ic.ac.uk/" + d['href']
        if(download_file_from_URL(name, local_file, false, d.text()))
          print_loading
          puts "\n\t...Success, saved as #{d.text()}"
        else 
          puts "\t...Skip, #{d.text()} already exists"
        end     
      end
    end
  end
  Dir.chdir(working_dir)
end # End download_exercises

def student_login()
################################################################################
#########################          CATe Login        ###########################
################################################################################
  # print "IC username: "
  # username = gets.chomp
  # print "IC password: "
  # system "stty -echo"
  # password = gets.chomp
  # system "stty echo"
  username = "dd2713"
  password = "dAyCHT8E"
  puts ""
  print "Class: " 
  classes = gets.chomp
  print "1 = Autumn\t2 = Christmas\t3 = Spring\t4 = Easter\t5 = Summer\nPeriod: "
  period = gets.chomp
  print "Academic year: "
  year = gets.chomp
  $student = $student.new(username, password, classes, period, year)
end

begin
  if(!ARGV.empty?)
    Dir.chdir(ARGV[0])
    ARGV.pop
  end
  create_directory("DoC Resources")
  Dir.chdir("Doc Resources")
  student_login()
  $rows, $cols = IO.console.winsize
  begin
    $agent = Mechanize.new
    $agent.add_auth('https://cate.doc.ic.ac.uk/' ,$student.username, 
                            $student.password, nil, "https://cate.doc.ic.ac.uk")
    $page = $agent.get("https://cate.doc.ic.ac.uk")
    puts "\nLogin Successful, welcome back #{$student.username}!\n"

    $page = $agent.
            get("https://cate.doc.ic.ac.uk/timetable.cgi?period=#{$student.period}" + 
                                "&class=#{$student.classes}&keyt=#{$student.year}%" + 
                                "3Anone%3Anone%3A#{$student.username}")
    links = $page.parser.xpath('//a[contains(@href, "notes.cgi?key")]').map { |link| link['href'] }.compact.uniq
    parse_cate_exercises()
    # parse_cate_notes(links)
  rescue Exception => e
    puts e.message
  end
  puts "\nAll done! =)"
rescue Exception => e
  puts "> Something went bad :(\n->" + e.message
end
