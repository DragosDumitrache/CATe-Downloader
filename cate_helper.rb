
require 'open-uri'

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
# :password => IC account password     - needed for downloading files off CATe
# :year     => current year on CATe    - 2014 (?)
# :classes  => either Computing or JMC - one of c1, c2, c3, j1, j2, j3 
Student = Struct.new(:username, :password, :year, :classes)


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# This represents a module in Computing course
#
# :name      => name of the module as shown on CATe
# :noteKyes  => array of FILE_NUMBER for the note files
# :exercises => array of Exercise structs for this module
_Module = Struct.new(:name, :noteNums, :noteURLs, :exercises)


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
def downloadFileFromURL(targetDir, fileURL, username, password, override)
  # puts targetDir + " " + fileURL + " " + username + " " + password + " "

  # Open file from web URL, using username and password provided
  fileIn = open(fileURL, :http_basic_authentication => [username, password])
  # Extract file name using this snippet found on SO
  begin 
    fileInName = fileIn.meta['content-disposition'].match(/filename=(\"?)(.+)\1/)[2]
  rescue Exception => e
    puts "Unable to find file name" + e.message
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


def downloadCATeFile(targetDir, student, fileNumber, fileType)
  return downloadFileFromURL(
    targetDir,
    getCATeFileURL(student, fileNumber, fileType),
    student.username,
    student.password,
    false)
end


def getCATeFileURL(student, fileNumber, fileType)
  return "https://cate.doc.ic.ac.uk/showfile.cgi?key=%s:%s:%s:%s:%s:%s" % [
    student.year, 
    "1", 
    fileNumber, 
    student.classes,
    fileType,
    student.username]
end


def downloadModuleNotes(moduleNotesDir, student, _module)
  _module.noteNums.each do |noteKey|
    if (downloadCATeFile(moduleNotesDir, student, noteKey, "NOTES"))
      puts "%2s:NOTES  #{_module.name} | Downloaded" % noteKey
    else
      puts "%2s:NOTES  #{_module.name} | Already exists!" % noteKey
    end
  end
  return
  _module.noteURLs.each do |noteURL|
    puts "NOTE URL: " + noteURL
    if (downloadFileFromURL(moduleNotesDir, noteURL, student.username, student.password, false))
      puts "Ur:NOTES  #{_module.name} | Downloaded"
    else
      puts "Ur:NOTES  #{_module.name} | Already exists!"
    end
  end
end


def downloadExercise(exerciseDir, student, exercise)
  if (downloadCATeFile(exerciseDir, student, exercise.specsNum, "SPECS"))
    puts "%2s:SPECS  #{exercise.name} | Downloaded" % exercise.specsNum
  else
    puts "%2s:SPECS  #{exercise.name} | Already exists!" % exercise.specsNum
  end

  if exercise.dataNum != -1
    if (downloadCATeFile(exerciseDir, student, exercise.dataNum, "DATA" ))
      puts "%2s:DATA   #{exercise.name} | Downloaded" % exercise.dataNum
    else
      puts "%2s:DATA   #{exercise.name} | Already exists!" % exercise.dataNum
    end
  end 

  if exercise.modelNum != -1
    if (downloadCATeFile(exerciseDir, student, exercise.modelNum, "MODELS")) 
      puts "%2s:MODELS #{exercise.name} | Downloaded" % exercise.modelNum
    else
      puts "%2s:MODELS #{exercise.name} | Already exist!" % exercise.modelNum
    end
  end
end


def downloadModules(folderName, student)

  # Create working directory  
  workingDir = Dir.pwd + "/" #+ folderName + "/"
  createDirectory(workingDir)

  MODULES.each do |_module|

    Dir.chdir(workingDir)
    createDirectory(_module.name)

    # Notes
    notesDir = _module.name + "/Notes"
    createDirectory(notesDir)
    downloadModuleNotes(notesDir, student, _module)

    _module.exercises.each do |exercise|
      # Exercises
      exerciseDir = _module.name + "/" + exercise.name
      createDirectory(exerciseDir)
      downloadExercise(exerciseDir, student, exercise)
    end  
  end
end

################################################################################

MODULES =
[
  _Module.new(
    "[220] Software Engeneering Design", # Module name
    [],  # Notes FILE_NUMBERs
    [ "http://www.doc.ic.ac.uk/~rbc/220/handouts/1-introduction.pdf",
      "http://www.doc.ic.ac.uk/~rbc/220/handouts/2-tdd-refactoring.pdf" ],
    [ Exercise.new("[1 CBT] Tut 1",  62, -1, -1),
      Exercise.new("[2 CBT] Tut 2", 112, -1, -1) ]), # Exercises 

  _Module.new(
    "[221] Compilers",
    [ 54, 55, 56, 58, 59, 186, 187, 189 ],
    [ "https://www.doc.ic.ac.uk/~nd/compilers/01_LexicalAnalysis.pdf",
      "https://www.doc.ic.ac.uk/~nd/compilers/02_BottomUp.pdf" ],
    [ Exercise.new("[1 CW] WACC Language Specification", 150, -1, -1) ]),

  _Module.new(
    "[223] Concurrency",
    [ 1, 2, 3, 4, 5, 6, 7, 8 ],
    [],
    [ Exercise.new("[1 TUT] Ch 1 and 2", 1, -1,  2),
      Exercise.new("[2 TUT] Ch 3",       3, -1, -1) ]),

  _Module.new(           
    "[240] Models of Computation", 
    [],
    [ "https://s3.amazonaws.com/piazza-resources/i0z753alu2mkr/i19n08jm21d1fw/lecture1.pdf?AWSAccessKeyId=AKIAJKOQYKAYOBKKVTKQ&Expires=1413684333&Signature=sOnL8nla5TzAjOK05vFAoDkkG3c%3D", 
      "https://s3.amazonaws.com/piazza-resources/i0z753alu2mkr/i1c0ibu2z5y3yr/lecture2.pdf?AWSAccessKeyId=AKIAJKOQYKAYOBKKVTKQ&Expires=1413684357&Signature=F%2FmNbOH381DjjcHOpOi8Yir872c%3D" ],
    []),

  _Module.new(
    "[245] Statistics",                       
    [ 120, 121, 133, 134 ], 
    [],
    [ Exercise.new("[2 TUT] Maths revision",      102, -1, -1),
      Exercise.new("[3 TUT] Numerical summaries", 104, -1, -1),
      Exercise.new("[4 TUT] Probability",         202, -1, -1) ]),

  _Module.new(
    "[261] Laboratory 2",                     
    [], 
    [],
    [ Exercise.new("[1 LAB] Linkload",   37, -1, -1),
      Exercise.new("[2 LAB] C++ Enigma", 59, -1, -1) ]),

  _Module.new(
    "[275] C++ Introduction",                 
    [ 34 ],  
    [],
    [ Exercise.new("[1 TUT] Lab 1", 40, 43, 46),
      Exercise.new("[2 TUT] Lab 2", 41, 44, 47),
      Exercise.new("[3 TUT] Lab 3", 42, 45, 48) ]),

  _Module.new(
    "[276] Introdution to Prolog",            
    [],  
    [],
    []),

  _Module.new(
    "[701] Programming Competition Training", 
    [],
    [],
    [])
]

################################################################################

begin
  puts "IC username: "
  username = gets.chomp

  puts "IC password: "
  system "stty -echo"
  password = gets.chomp
  system "stty echo"
  #puts username + " " + password

  student = Student.new(username, password, "2014", "c2")

  downloadModules("CATe Autumn Term 2014-2015", student) 

  puts "\nAll done! =)"
rescue Exception => e
  puts "> Something went bad :(\n->" + e.message
end
