#!/bin/bash
#===============================================================================
#
#          FILE:  runpar.sh
# 
#         USAGE:  ./runpar.sh [options - see below] [--] [files]
# 
#   DESCRIPTION:  Parallel processing from the argument list
# 
#       OPTIONS:  see USAGE below
#  DEPENDENCIES:  date grep ps sleep which
#        AUTHOR:  Dr.-Ing. Fritz Mehner (fgm), mehner@web.de
#       VERSION:  1.1
#       CREATED:  08.01.2009 21:21:09 CET
#      REVISION:  ---
#
#  This program is free software; you can redistribute it and/or modify 
#  it under the terms of the GNU General Public License as published by 
#  the Free Software Foundation; either version 2 of the License, or    
#  (at your option) any later version.                                  
#
#===============================================================================
shopt -s nullglob
set -o nounset    

#===  FUNCTION  ================================================================
#          NAME:  usage
#   DESCRIPTION:  display usage message
#===============================================================================
usage ()
{
  printf "
  usage: $SCRIPT [options] [--] [files]

  -c <command>    command, needs files to process
  -C <file>       command file
  -d <delay>      delay between checks for terminated processes (default 0.1 [seconds])
  -D <delay>      delay between max_proc processes (format: digits[smhd] ) 
  -f <file>       file containing filenames to process
  -h              Display this information
  -l <file>       logfile name
  -L <limit>      runtime limit (seconds), default is 0 (no runtime check) 
  -p <max_proc>   maximal number of parallel processes
  -v              display simple progress indicator
  "
} # ----------  end of function usage  ----------

#===============================================================================
#   GLOBAL DECLARATIONS
#===============================================================================
declare -r  SCRIPT=${0##*/}
declare     COMMAND=''
declare -r  CPUINFO='/proc/cpuinfo'
declare     DELAY=0
declare     CMDTYPE='none'
declare -i  VERBOSE=0
declare -i  LIMIT=0
declare     INFILENAME="/dev/stdin"             # default input source
declare     LOGFILE="LOGFILE.${SCRIPT}.${$}"
declare -i  MAXPROCESS=4                        # processes running at the same time
declare     SWITCH

declare     shortsleep='0.1'                    # used by the dispatcher loop
declare -a  pid                                 # PIDs of the child processes
declare -i  jobsstarted=0                       # job counter
declare -a  jobsfinished=0
declare     item

if [ $# -eq 0 ] ; then
  printf "%s\n" "Type '$SCRIPT -h' for help."
  exit 4
fi

#-------------------------------------------------------------------------------
#  PROCESS PARAMETER LIST
#-------------------------------------------------------------------------------
if [ -e "$CPUINFO" ] ; then
  MAXPROCESS=$( grep -c ^processor "$CPUINFO" )
  ((MAXPROCESS*=2))
fi

declare -r  OPTIONSTRING='hc:C:d:D:f:l:L:p:v'

while getopts "$OPTIONSTRING" SWITCH ; do
  case $SWITCH in

    h)  usage
        exit 0
        ;;

    c)  COMMAND=$( which ${OPTARG%% *} 2> /dev/null ) # needs -f
        if [ ! -x "$COMMAND" ] ; then
          printf "$SCRIPT: command '%s' not found or not executable\n" $COMMAND
          exit 2
        fi
        CMDTYPE='filelist'
        ;;

    C)  INFILENAME="$OPTARG"
        CMDTYPE='cmdfile'
        ;;

    d)  [[ $OPTARG =~ ^[0-9]*\.?[0-9]+$ ]] && shortsleep=$OPTARG
        ;;

    D)  [[ $OPTARG =~ ^[0-9]+[smhd]?$ ]] && DELAY="$OPTARG"
        ;;

    f)  INFILENAME="$OPTARG"
        CMDTYPE='filelist'                      # needs -c
        ;;

    l)  LOGFILE="$OPTARG"
        ;;

    L)  [[ $OPTARG =~ ^[0-9]+$ ]] && LIMIT="$OPTARG"
        ;;

    p)  [[ $OPTARG =~ ^[0-9]+$ ]] && MAXPROCESS="$OPTARG"
        ;;

    v)  VERBOSE=1
        ;;

    -)  break
        ;;

    *)  printf "$SCRIPT: %s\n" 'error: unhandled argument'
        exit 1
        ;;

  esac    # --- end of case ---
done

shift $((OPTIND-1))                             # shift past options

#-------------------------------------------------------------------------------
#  PARAMETER CHECKS
#-------------------------------------------------------------------------------
if [ $CMDTYPE == 'filelist' ] && [ -z $COMMAND ]; then
  printf "no command specified (use also option -c)\n" 
  exit 3
fi
if [ $CMDTYPE == 'none' ] ; then
  printf "no command specified (use also option -c)\n" 
  exit 3
fi

#===  FUNCTION  ================================================================
#          NAME:  check_children
#   DESCRIPTION:  check for finished child processes
#===============================================================================
check_children ()
{
  for p in ${!pid[@]}; do                     # check running children
    kill -0 $p 2> /dev/null                   # child alive?
    if [ $? -ne 0 ] ; then                    # child has finished
      unset -v 'pid[$p]'                      # remove child PID
      ((jobsfinished++))
    else
      #
      # check for long running process
      now=$( date +%s )
      if [ $LIMIT -gt 0 ] && [ $((now-pid[p])) -gt $LIMIT ] ; then
        printf "process %6d runs for %10d seconds\n" $p $((now-pid[$p])) >> "$LOGFILE"
        # 
        # PID wrap around and capturing ?
        parent=$( ps --no-headers -o ppid $p )
        if [[ $parent =~ ^[[:space:]]*[[:digit:]]+$ ]] && [ $parent -ne $$ ] ; then
          unset 'pid[$p]'                     # remove child PID
          ((jobsfinished++))
          printf "process %6d removed\n" $p >> "$LOGFILE"
        fi

      fi
    fi
  done
  [ $VERBOSE -gt 0 ] && printf "\b\b\b\b\b\b%6b" $jobsfinished
} # ----------  end of function check_children  ----------

#===  FUNCTION  ================================================================
#          NAME:  kernel
#   DESCRIPTION:  start command and control command termination inside the main
#                 loop below
#===============================================================================
kernel ()
{
  #-------------------------------------------------------------------------------
  #  check for terminated children
  #-------------------------------------------------------------------------------
  until [ ${#pid[@]} -lt $MAXPROCESS ] ; do     # can we start a new process?
    sleep $shortsleep                           # wait a short time
    check_children
  done

  #-------------------------------------------------------------------------------
  #  start a new process
  #-------------------------------------------------------------------------------
  case $CMDTYPE in
    cmdfile)                                    # input from a command file
    eval "${item} &>> ${LOGFILE} &"
    pid[$!]=$( date +%s )                       # store child PID 
    ;;

    filelist)                                   # input from STDIN
    eval "${COMMAND} ${item} &>> ${LOGFILE} &"
    pid[$!]=$( date +%s )                       # store child PID 
    ;;

    *)
    break
    ;;
  esac    # --- end of case ---

  ((jobsstarted++))                             # increment number of jobs
  #-------------------------------------------------------------------------------
  #  start longsleep
  #-------------------------------------------------------------------------------
  [[ ${DELAY%[smhd]}        -gt 0 ]] && \
  [[ jobsstarted%MAXPROCESS -eq 0 ]] && \
  sleep $DELAY
} # ----------  end of function kernel  ----------

#===  FUNCTION  ================================================================
#          NAME:  cleanup
#   DESCRIPTION:  wait for active children, remove empty logfile, exit
#    PARAMETERS:  ---
#===============================================================================
cleanup ()
{
  wait                                          # wait for active children 
  printf "\n$SCRIPT: %d jobs started / %d finished\n" $jobsstarted $jobsfinished
  if [ -s "$LOGFILE" ] ; then
    printf "$SCRIPT: logfile '%s' created\n" $LOGFILE
  else
    rm --force "$LOGFILE"
  fi
  exec  3<&-                                    # close file descriptor
  exit 0
} # ----------  end of function cleanup  ----------

#===============================================================================
#   TRAPS
#===============================================================================
trap  cleanup SIGINT                            # wait for children

#===============================================================================
#   MAIN SCRIPT
#===============================================================================

exec 3<"$INFILENAME"                            # open input file
if [ $? -ne 0 ] ; then
  printf "Could not link file descriptor with file '%s'\n" $INFILENAME
  exit 1
fi

[ $VERBOSE -gt  0 ] && printf "\n number of parallel processes : %d" $MAXPROCESS
[ $VERBOSE -gt  0 ] && printf "\n jobs finished %6d" 

#-------------------------------------------------------------------------------
#  main loop
#-------------------------------------------------------------------------------
if [ -z "$*" ] ; then
  while read -u 3 item ; do             # filenames come from STDIN or a file
    kernel
  done
else
  for item in  "$@" ; do                # filenames come from the argument list
    kernel
  done
fi

#-------------------------------------------------------------------------------
#  wait for running child processes
#-------------------------------------------------------------------------------
while [ ${#pid[@]} -gt 0 ] ; do                 # can we start a new process?
  sleep $shortsleep                             # wait a short time
  check_children
done

#===============================================================================
#   STATISTICS / CLEANUP
#===============================================================================
cleanup                                         # display report, ... , exit

