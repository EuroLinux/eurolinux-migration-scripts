#!/bin/bash
# name: wrapper.sh
#
# description: Easily run migration tests - just provide the boxes to operate
# on and the tests you want to run (or don't provide them to run all of them)
#
# Copyright 2021 EuroLinux, Inc.
# Author: Tomasz Podsiadły <tp@euro-linux.com>

usage() {
"USAGE
${0##*/} -b box1 box2 box3         - operate on these boxes
${0##*/} -t test1 test2 test3      - run selected tests (directories
                                     in ./EL-core-functional-tests/tests/ or
                                     standalone scripts in them)
${0##*/} (illegal or no options)   - print this message"
}

while getopts "b:t:" opt; do
  case $opt in
    b) 
       # Get several boxes to the -b option so you can use `-b box1 box2
       # box3` rather than `-b box1 -b box2 -b box3`. 
       boxes=("$OPTARG")
       until [[ $(eval "echo \${$OPTIND}") =~ ^-.* ]] || \
         [ -z $(eval "echo \${$OPTIND}") ]
       do
           boxes+=($(eval "echo \${$OPTIND}"))
           OPTIND=$((OPTIND + 1))
       done
       ;;
    t) 
       # Similarly get several tests with -t
       tests=("$OPTARG")
       until [[ $(eval "echo \${$OPTIND}") =~ ^-.* ]] || \
         [ -z $(eval "echo \${$OPTIND}") ]
       do
           tests+=($(eval "echo \${$OPTIND}"))
           OPTIND=$((OPTIND + 1))
       done
       ;;
    *) echo #newline
       usage
       exit 1
       ;;
  esac
done
shift $((OPTIND -1))

# Go one directory up the one with the script (the project's base directory
# where Vagrantfile is located)
script_dir=$(dirname $(readlink -f $0))
cd "$script_dir"/../ || exit 1

# Once this wrapper has been executed, log that information in all
# provided-as-parameters-boxes' log files.
for box in ${boxes[*]}; do
  printf "Session started at %(%Y.%m.%d %H:%M:%S)T\n" \
    | tee -a "${box}_migration_tests.log"
done

# Perform tests per each box
for box in ${boxes[*]}; do
  vagrant rsync "$box"
  # Run the tests by executing the already-rsynced run_migration_test.sh
  # script that will take care of the actual execution of the tests with
  # everything happening in a box and skipping problematic tests per distro.
  vagrant ssh "$box" -c \
    "cd /vagrant/tests && ./run_migration_test.sh ${tests[*]}" \
      | tee -a "${box}_migration_tests.log"
done

# Once this wrapper finished with all the migration tests, log that
# information in all provided-as-parameters-boxes' log files.
for box in ${boxes[*]}; do
  printf "Session ended at %(%Y.%m.%d %H:%M:%S)T\n" \
    | tee -a "${box}_migration_tests.log"
done
