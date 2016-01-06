README for runpar.sh (Version 1.1) / January 06 2016
================================================================================

  *  INSTALLATION
  *  USAGE
  *  FILES
  *  AUTHOR

`runpar.sh`  is  a  shell  script that executes commands in parallel, but their
number is limited to an adjustable value.

With one CPU `runpar.sh` can be used to spread  the  load.   If  multiple CPUs
are available, processes can be executed in parallel.

INSTALLATION
================================================================================

(1) Installing the shell script
--------------------------------------------------------------------------------

Make the script executable. Run it from your working directory as 

    ./runpar.sh  ...

or copy it to `~/bin`, or put a link into `~/bin` to the directory containing
`runpar.sh`.

(2) Installing the manual
--------------------------------------------------------------------------------

The manual page can be installed in a system-wide directory (as an
administrator). To see the locations run

    manpath

To install the manual in the users home directory put the following line into
`~/.profile`

    export MANPATH="$(manpath):/home/<my_home_dir>/man"

then create `~/man/man1` (if it doesn't exit) and copy `runpar.1` to this
directory.  After your next login read the manual with

    man runpar

USAGE
================================================================================

(1) Synopsis
--------------------------------------------------------------------------------

    runpar.sh [options] [--] [files]

(2) Options
--------------------------------------------------------------------------------

    -c <command>
           Command to execute in parallel; needs files to process.

    -C <file>
           Use command file with one complete command per line.

    -d <delay>
           Delay between checks for terminated processes (default 0.1 [seconds]).

    -D <delay>
           Additional delay between max_proc processes (format: digits[smhd] ).

    -f <file>
           Specify file containing filenames to process (needs -c).

    -h     Display the help text.

    -l <file>
           Set the log file name (default: LOGFILE.runpar.sh.<PID>).

    -L <limit>
           Runtime limit (seconds), default is 0 (no runtime check); processes
           running longer then <limit> will be logged.

    -p <max_proc>
           Start the specified number of processes in parallel. Ignore the
           number of CPUs.

    -v     Display a simple progress indicator.

(3) Examples
--------------------------------------------------------------------------------

Generate Postscript files from all PDF files in the working directory:

    runpar.sh -c pdf2ps *.pdf

Generate Postscript files from all PDF files in the working directory:

    ls *.pdf | runpar.sh -c pdf2ps

Generate Postscript files from all PDF files in the working directory; allow 4
parallel processes:

    ls *.pdf | runpar.sh -p 4 -c pdf2ps

Generate  PDFs files from all eps-files listed in the file files.list; allow 4
parallel processes; display progress indicator; log processes running longer
then 10 seconds:

    runpar.sh -c epstopdf -p 4 -v -L 10 -f files.list

Run all commands from file `commands.list` :

    runpar.sh -C commands.list

(4) EXIT STATUS
--------------------------------------------------------------------------------

    0    success
    1    unknown option
    2    command not found or not executable
    3    no command given
    4    missing command line option(s)


FILES
================================================================================

    README.md   this file
    runpar.sh   the shell script
    runpar.1    the man page

AUTHOR
================================================================================
Dr. Fritz Mehner (fgm), fritz.mehner@web.de

