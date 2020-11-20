CATe-Downloader
===============

Downloads notes/specs/data_files/model_answers for all CATe modules and exercises. 

Courtesy of Mearlboro and Zemellino for creating the original script.

# How to use:
Simply run the script in the terminal, either as ./cate_helper.rb or ruby cate_helper.rb. If it's the first time the script is run on your machine, it will install its dependencies, which might take some time.

Required information:
  - Username: Your IC username
  - Password: Your IC password
  - Class: The course year you're in i.e c1, c2, j1, j2
  - Academic Year: The academic year in which you started your class
  - Period: 1 = Autumn 2 = Christmas 3 = Spring 4 = Easter 5 = Summer

```shellscript
Usage: **./cate_helper.rb [options] [optional-path]

Specific options:
    -p, --path                       Download all materials to path or PWD
    -h, --help                       Show this message
If you simply want to download everything in the same location, do not provide any flags or path  
```


# What's new:
v2.2 
  - Automatic installation of missing dependencies
  - Support for second year OS and Networks courses


# Updates history:
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

v2.0 
  - Added support for Piazza Notes, Exercises and Model answers download manually
  - Updated with the latest URLs for notes/specs/data_files/model_answers
  - Aligned output strings to a terminal width of 80

# TODO:
  - [x] Add support for downloading data files and model answer
  - [ ] Add support for downloading files from Piazza
  - [x] Check CATe credentials before any downloads commence
