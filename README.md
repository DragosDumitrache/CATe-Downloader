CATe-Downloader
===============

Downloads notes/specs/data_files/model_answers for all CATe modules and exercises. 

Courtesy of Mearlboro and Zemellino for creating the original script.

#How to use:
If you've never run this script before, chances are you're missing a few gems. To install everything you need, run **./installer.rb**. Once that's finished, you are free to run the ./cate_helper.rb.

Usage: **./cate_helper.rb [optional-dir]**. If [optional-dir] is not null, the notes will be downloaded in that directory. In the event that no path is provided, the notes will be downloaded into the current directory.
  
#What's new:
v2.1
  - Turned into a web parser that downloads notes and exercises automatically
  - Checks CATe credentials before any downloads commence
  - Changed output format
  - Required information:
    - Username: Your IC username
    - Password: Your IC password
    - Class: The course year you're in i.e c1, c2, j1, j2
    - Academic Year: The academic year in which you started your class
    - Period: 1 = Autumn 2 = Christmas 3 = Spring 4 = Easter 5 = Summer

#Updates history:
v2.0 
  - Added support for Piazza Notes, Exercises and Model answers download manually
  - Updated with the latest URLs for notes/specs/data_files/model_answers
  - Aligned output strings to a terminal width of 80

#TODO:
  - [ ] Add support for downloading data files and model answer
  - [ ] Add support for downloading files from Piazza
  - [x] Check CATe credentials before any downloads commence
