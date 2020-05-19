:: Compile batch script to automate build process
:: Author | Ryan Kim
:: Original version | 2020-5-19

:: Usage:
::    .\compile.bat <source folder> <build folder> <assembler_flag>
::    Will compile *.c files and link with *.s files in <source folder> and compile them into <build folder>. If no flag is passed to <assembler_flag>, no *.s files will be assembled into object files.
:: requires cc65, ca65, ld65 (cc65 package), and x64sc (part of VICE C64 Emulator) to be in PATH variable


@echo off
setlocal EnableDelayedExpansion

if "%1"=="" (
  echo Source folder not defined. & EXIT /B 1
)
if "%1"=="-h" (
  echo compile.bat [-hc] ^<source folder^> ^<build folder^> ^<assembler_flag^> ^<final compiled name^> ^<launch_flag^>
  echo      [-h] - Prints this message.
  echo      [-c] - Cleans log files.
  echo      ^<source folder^> - specify where all C files and supplementary *.s may be. All *.s files in this directory will be placed in a subdirectory ^<asm^>.
  echo      ^<build folder^> - specify where build binaries should be placed.
  echo      ^<assembler_flag^> - if -a is passed here, then the script will continue on to compile the asssembly files into a binary.
  echo      ^<final compiled name^> - specify what the final binary's name should be.
  echo      ^<launch_flag^> - if -l is passed here, then the script will attempt to launch the binary in VICE x64sc.
  EXIT /B %ERRORLEVEL%
)
if "%1"=="-c" (
  goto clean_logs
)

if "%2"=="" (
  echo Build folder not defined. & EXIT /B 1
)

set source=%1
set build=%2
set binary=%4

echo Source folder: %source%
echo Build folder: %build%
echo Final Binary Name: %binary%

if [%3]==[-a] (
  set asmflag="true"
  echo Assembler flag set.
) else (
  set asmflag="false"
  echo Assembler flag not set.
)

if [%5]==[-l] (
  set launchflag="true"
  echo Launch flag set.
) else (
  set launchflag="false"
  echo Launch flag not set.
)



rem MAIN COMPILE SEQUENCE
:main
  set /A i=0
  mkdir log >NUL

  echo.
  echo Entering source folder...
  cd %source%
  mkdir asm >NUL
  rem echo %CD%

  rem Move all *.s files into "asm" folder for easy compilation
  for %%a in ("*.s") do (
    move %%a asm\%%a
  )


  rem Find and index all *.c files
  echo.
  echo Indexing *.c files...

  for %%a in ("*.c") do (
    set cfiles[!i!]=%%a
    set /A i+=1
  )


  echo Index finished.

  if %i%==0 (
    echo No *.c files detected, exiting.
    exit
  ) else (
    echo.
    set /A i-=1
  )


  rem Goes through indexed *.c files and compiles them into <asm>
  for /l %%n in (0,1,%i%) do (
    echo Compiling !cfiles[%%n]! to assembly...

    rem Need this b/c default %TIME% and %DATE% have illegal characters for file names
    set nowdate=!DATE:/=-!
    set nowtime=!TIME::=-! & set nowtime=!nowtime:~0,-4!

    rem Logs verbose output of cc65 in <source file name>
    rem Also this is most unreadable line of code I've ever written
    cc65 -O -v -t c64 -o asm\!cfiles[%%n]:.c=.s! !cfiles[%%n]! >..\log\!cfiles[%%n]!_!nowdate!_!nowtime!.txt
  )
  echo.
  echo Finished *.c compilation.

  if %asmflag%=="false" (
    echo Assembler flag not set, exiting now. & EXIT /B %ERRORLEVEL%
  ) else (
    echo Assembler flag set, continuing with script.
  )

  echo.
  echo Entering ^<asm^> folder...
  cd asm

  set /A i=0

  echo Indexing assembly files...

  for %%a in ("*.s") do (
    set asmfiles[!i!]=%%a
    set /A i+=1
  )
  set /A i-=1

  for /l %%n in (0,1,%i%) do (
    echo Compiling !asmfiles[%%n]! to object file...

    set nowdate=!DATE:/=-!
    set nowtime=!TIME::=-! & set nowtime=!nowtime:~0,-4!

    ca65 -t c64 -v -o ..\..\build\!asmfiles[%%n]:.s=.o! !asmfiles[%%n]! >..\..\log\!asmfiles[%%n]!_!nowdate!_!nowtime!.txt
  )

  echo Finished *.s compilation.
  echo.
  echo Entering ..\..\%build%...
  cd ..\..\%build%


  set objfiles=

  for %%a in ("*.o") do (
    set objfiles=!objfiles! %%a
  )

  set objfiles=%objfiles:~1%
  echo %objfiles%


  rem Links together all *.o files in the build directory.
  ld65 -o %binary% -t c64 -v %objfiles% c64.lib

  echo.
  echo Finished linking object files.
  echo Cleaning up object files.
  del "*.o"



  if %launchflag%=="false" (
    echo Launch flag not set, exiting now. & EXIT /B %ERRORLEVEL%
  ) else (
    echo Launch flag set, attempting launch.
  )

  set nowdate=%DATE:/=-%
  set nowtime=%TIME::=-% & set nowtime=%nowtime:~0,8%
  x64sc -logfile "..\log\%binary%LAUNCH_%nowdate%_%nowtime%.txt" -autostart %binary%


  EXIT /B %ERRORLEVEL%

:clean_logs
  echo Cleaning old logs...
  cd log
  del *.txt
  EXIT /B %ERRORLEVEL%
