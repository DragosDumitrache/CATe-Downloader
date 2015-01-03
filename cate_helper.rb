#!/usr/bin/ruby

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


def downloadCATeFile(targetDir, student, fileNumber, fileType)
  return downloadFileFromURL(
    targetDir,
    getCATeFileURL(student, fileNumber, fileType),
    student,
    false,
    "")
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

def download_piazza_file(target_dir, file_id, student, file_in_name)
  return downloadFileFromURL(
    target_dir,
    get_piazza_URL(file_id),
    student,
    false,
    file_in_name)
end 

def get_piazza_URL(file_id)
  return "https://piazza.com/class_profile/get_resource/i0z753alu2mkr/" + file_id
end


def downloadModuleNotes(moduleNotesDir, student, _module)
   sizel = 42 - _module.name.length
  if(!_module.noteNums.empty?)
    _module.noteNums.each do |noteKey|
      if (downloadCATeFile(moduleNotesDir, student, noteKey, "NOTES"))
        puts "%3s:NOTES\t#{_module.name}%#{sizel}s|%10sDownloaded!" % [noteKey, "",""]
      else
        puts "%3s:NOTES\t#{_module.name}%#{sizel}s|%6sAlready exists!" % [noteKey, "", ""]
      end
    end
  end
  if(!_module.noteURLs.empty?)
    _module.noteURLs.each do |noteURL|
      # puts "NOTE URL:\t" + noteURL
      if (downloadFileFromURL(moduleNotesDir, noteURL, student, false, ""))
        puts "Ur:NOTES\t#{_module.name}%#{sizel}s|%10sDownloaded!" % ["", ""]
      else
        puts "Ur:NOTES\t#{_module.name}%#{sizel}s|%6sAlready exists!" % ["", ""]
      end
    end
  end
end


def downloadExercise(exerciseDir, student, exercise)
  sizel = 42 - exercise.name.length
  if (downloadCATeFile(exerciseDir, student, exercise.specsNum, "SPECS"))
    puts "%3s:SPECS\t#{exercise.name}%#{sizel}s|%10sDownloaded!" % [exercise.specsNum, "", ""]
  else
    puts "%3s:SPECS\t#{exercise.name}%#{sizel}s|%6sAlready exists!" % [exercise.specsNum , "", ""]
  end

  if (exercise.dataNum != -1)
    if (downloadCATeFile(exerciseDir, student, exercise.dataNum, "DATA" ))
      puts "%3s:DATA\t#{exercise.name}%#{sizel}s|%10sDownloaded!" % [exercise.dataNum, "", ""]
    else
      puts "%3s:DATA\t#{exercise.name}%#{sizel}s|%6sAlready exists!" % [exercise.dataNum, "", ""]
    end
  end 

  if (exercise.modelNum != -1)
    if (downloadCATeFile(exerciseDir, student, exercise.modelNum, "MODELS"))
      puts "%3s:MODELS\t#{exercise.name}%#{sizel}s|%10sDownloaded!" % [exercise.modelNum, "", ""]
    else
      puts "%3s:MODELS\t#{exercise.name}%#{sizel}s|%6sAlready exists!" % [exercise.modelNum, "", ""]
    end
  end
end

def download_piazza_exercise(exercise_dir, student, exercise)
  sizel = 42 - exercise.name.length
  if (download_piazza_file(exercise_dir, exercise.specsNum, student, "Tut " + exercise.name + ".pdf"))
    puts "Ur:SPECS\t#{exercise.name}%#{sizel}s|%10sDownloaded!" % ["", ""]
  else
    puts "Ur:SPECS\t#{exercise.name}%#{sizel}s|%6sAlready exists!" % ["", ""]
  end
  if (exercise.dataNum != -1)
    if (download_piazza_file(exercise_dir, exercise.dataNum, student, "Data " + exercise.name + ".pdf" ))
      puts "Ur:DATA\t#{exercise.name}%#{sizel}s|%10sDownloaded!" % ["", ""]
    else
      puts "Ur:DATA\t#{exercise.name}%#{sizel}s|%6sAlready exists!" % ["", ""]
    end
  end 
  if (exercise.modelNum != -1)
    if (download_piazza_file(exercise_dir, exercise.modelNum, student, "Answers " + exercise.name + ".pdf"))
      puts "Ur:MODELS\t#{exercise.name}%#{sizel}s|%10sDownloaded!" % ["", ""]
    else
      puts "Ur:MODELS\t#{exercise.name}%#{sizel}s|%6sAlready exists!" % ["", ""]
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
    if(!_module.exercises.empty?)
      _module.exercises.each do |exercise|
        # Exercises
        exerciseDir = _module.name + "/" + exercise.name
        createDirectory(exerciseDir)
        downloadExercise(exerciseDir, student, exercise)
      end  
    end
    if(!_module.piazza_exercises.empty?) 
      _module.piazza_exercises.each do |exercise|
        exerciseDir = _module.name + "/" + exercise.name
        createDirectory(exerciseDir)
        download_piazza_exercise(exerciseDir, student, exercise)
      end
    end
  end
end

################################################################################

MODULES =
[
  _Module.new(
    "[220] Software Engeneering Design", # Module name
    [],  # Notes FILE_NUMBERS
    [ "http://www.doc.ic.ac.uk/~rbc/220/handouts/1-introduction.pdf",
      "http://www.doc.ic.ac.uk/~rbc/220/handouts/2-tdd-refactoring.pdf",
      "http://www.doc.ic.ac.uk/~rbc/220/handouts/4-mocks.pdf",
      "http://www.doc.ic.ac.uk/~rbc/220/handouts/5-TDA.pdf",
      "http://www.doc.ic.ac.uk/~rbc/220/handouts/6-reuse.pdf",
      "http://www.doc.ic.ac.uk/~rbc/220/handouts/7-metrics.pdf",
      "http://www.doc.ic.ac.uk/~rbc/220/handouts/8-hofs.pdf",
      "http://www.doc.ic.ac.uk/~rbc/220/handouts/9-mapreduce.pdf",
      "http://www.doc.ic.ac.uk/~rbc/220/handouts/10-concurrency.pdf",
      "http://www.doc.ic.ac.uk/~rbc/220/handouts/11-pub-sub.pdf",
      "http://www.doc.ic.ac.uk/~rbc/220/handouts/12-creation.pdf",
      "http://www.doc.ic.ac.uk/~rbc/220/handouts/13-seams-sensing.pdf",
      "http://www.doc.ic.ac.uk/~rbc/220/handouts/14-interactive.pdf",
      "http://www.doc.ic.ac.uk/~rbc/220/handouts/15-webapps.pdf",
      "http://www.doc.ic.ac.uk/~rbc/220/handouts/16-system-integration.pdf",
      "http://www.doc.ic.ac.uk/~rbc/220/handouts/17-distribution.pdf",
      "http://www.doc.ic.ac.uk/~rbc/220/handouts/18-revision.pdf" ],
    [ Exercise.new("[1 CBT] Tut 1",  62, -1, -1),
      Exercise.new("[2 CBT] Tut 2", 112, -1, -1),
      Exercise.new("[3 CBT] Tut 3", 230, -1, -1),
      Exercise.new("[4 CBT] Tut 4", 323, -1, -1),
      Exercise.new("[5 CBT] Tut 5", 399, -1, -1),
      Exercise.new("[6 CBT] Tut 6", 461, -1, -1),
      Exercise.new("[7 CBT] Tut 7", 526, -1, -1),
      Exercise.new("[8 CBT] Tut 8", 568, -1, -1) ], # Exercises
    []), # Piazza Exercises

  _Module.new(
    "[221] Compilers",
    [ 54, 55, 56, 58, 59, 186, 187, 189 ],
    [ "https://www.doc.ic.ac.uk/~nd/compilers/01_LexicalAnalysis.pdf",
      "https://www.doc.ic.ac.uk/~nd/compilers/02_BottomUp.pdf" ],
    [ Exercise.new("[1 CW] WACC Language Specification", 150, -1, -1),
      Exercise.new("[2 CW] HaskellFunctionCalls",        264, -1, -1) ],
    []),

  _Module.new(
    "[223] Concurrency",
    [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 ],
    [],
    [ Exercise.new("[1 TUT] Ch 1 and 2", 1, -1,  2),
      Exercise.new("[2 TUT] Ch 3",       3, -1,  4),
      Exercise.new("[3 TUT] Ch 4 and 5", 5, -1, 6),
      Exercise.new("[4 CW] CW 1",        7, -1, -1),
      Exercise.new("[5 TUT] Ch 6", 10, -1, 9),
      Exercise.new("[6 TUT] Ch 7", 11, -1, 12),
      Exercise.new("[7 CW] CW 2", 13, 15, -1) ],
    []),

  _Module.new(           
    "[240] Models of Computation", 
    [],
    [ "https://piazza.com/class_profile/get_resource/i0z753alu2mkr/i19n08jm21d1fw", 
      "https://piazza.com/class_profile/get_resource/i0z753alu2mkr/i1c0ibu2z5y3yr",
      "https://piazza.com/class_profile/get_resource/i0z753alu2mkr/i24fe7asmi81cs",
      "https://piazza.com/class_profile/get_resource/i0z753alu2mkr/i2eim9e212l4s4",
      "https://piazza.com/class_profile/get_resource/i0z753alu2mkr/i2f983myleq1o9",
      "https://piazza.com/class_profile/get_resource/i0z753alu2mkr/i2xtq0ie6961x",
      "https://piazza.com/class_profile/get_resource/i0z753alu2mkr/i38ir5cmf18363",
      "https://piazza.com/class_profile/get_resource/i0z753alu2mkr/i3a2xb25m4l27m",
      "https://piazza.com/class_profile/get_resource/i0z753alu2mkr/i3k18f71dtr2xn" ],
    [],
    [ Exercise.new("[1 CW] CW 1", "i257sx7j32mhr", -1, "i3izldiaqlk6nd"),
      Exercise.new("[2 CW] CW 2", "i37vi1gl2j76x7", -1, -1),
      Exercise.new("1: Expressions", "i1aj65c0wzn2nj", -1, "i1hzzj582ba25m"),
      Exercise.new("2: State", "i1t71ggkvxw7b0", -1, "i1ut463yyxt5b"),
      Exercise.new("3: Induction", "i21s0yii5r1d6", -1, "i2dkvyqhc064ly"),
      Exercise.new("4: Register Machine", "i2oj11iagqc61d", -1, "i2wew6m5c6nr9"),
      Exercise.new("5: Universal Register Machine", "i2wex4jnf441rp", -1, "i30h9cnr9ln66j"),
      Exercise.new("6: Turing Machines", "i3iyl6br7078x", -1, "i3iynypfk5u20q"),
      Exercise.new("7: Lambda Calculus 1", "i3iylnzfozrg1", -1, "i3iyo84aid96hl"),
      Exercise.new("8: Lambda Calculus 2", "i3iylwk5oz27oj", -1, "i3iyok8nobk6mb") ]),

  _Module.new(
    "[245] Statistics",                       
    [ 120, 121, 133, 134, 224 , 273, 321, 375, 406, 457, 250], 
    [],
    [ Exercise.new("[2 TUT] Maths revision",      102, -1, 103),
      Exercise.new("[3 TUT] Numerical summaries", 104, -1, 105),
      Exercise.new("[4 TUT] Probability",         202, -1, 203),
      Exercise.new("[5 TUT] Further Probability", 220, -1, 221),
      Exercise.new("[6 TUT] Discrete Random Variables", 287, -1, 288),
      Exercise.new("[7 TUT] Continuous Random Variables", 353, -1, 354),
      Exercise.new("[8 TUT] Example question for Feedback", 384, -1, 604),
      Exercise.new("[10 TUT] Estimation", 491, -1, 490),
      Exercise.new("[1 CW] Statistics coursework", 418, -1, -1),
      Exercise.new("[11 TUT] Hypothesis Testing", 541, -1, 542),
      Exercise.new("[12 TUT] Reliability", 658, -1, 659) ],
    []),

  _Module.new(
    "[261] Laboratory 2",                     
    [], 
    [],
    [ Exercise.new("[1 LAB] Linkload",          37, -1, -1),
      Exercise.new("[2 LAB] C++ Enigma",        59, -1, -1),
      Exercise.new("[3 LAB] WACC - Front End", 226, -1, -1),
      Exercise.new("[4 LAB] WACC - Back End", 227, -1, -1),
      Exercise.new("[5 LAB] WACC - Extension", 335, -1, -1) ],
    []),

  _Module.new(
    "[275] C++ Introduction",                 
    [ 34 ],  
    [],
    [ Exercise.new("[1 TUT] Lab 1", 40, 43, 46),
      Exercise.new("[2 TUT] Lab 2", 41, 44, 47),
      Exercise.new("[3 TUT] Lab 3", 42, 45, 48) ],
    []),

  _Module.new(
    "[276] Introduction to Prolog",            
    [ 343, 486, 487, 488, 489, 490 ],  
    [],
    [],
    []),

  _Module.new(
    "[701] Programming Competition Training", 
    [],
    [],
    [],
    [])
]

################################################################################

begin
  print "IC username: "
  username = gets.chomp
  print "IC password: "
  system "stty -echo"
  password = gets.chomp
  system "stty echo"
  puts ""
  puts "Fetching everything you need to succeed, this might take a while"
  student = Student.new(username, password, "2014", "c2")

  downloadModules("CATe Autumn Term 2014-2015", student) 

  puts "\nAll done! =)"
rescue Exception => e
  puts "> Something went bad :(\n->" + e.message
end
