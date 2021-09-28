#!/bin/bash
# name: run_migration_test.sh
#
# description: Run migration-related tests provided as parameters.
# This script shall be ran **inside** a box with the necessary files rsynced
# (the whole project's directory by default). With automated tests you'll most
# likely want to `vagrant up box`, ensuring that this script landed in a box,
# first and run this script with a wrapper executed on a **Vagrant host** like:
# `vagrant ssh box -c "cd /vagrant/tests && \
#   ./run_migration_test.sh test1 test2 test3" | tee -a my_tests_logs.log`
#
# Copyright 2021 EuroLinux, Inc.
# Author: Kamil Halat <kh@euro-linux.com>
# Author: Tomasz Podsiadły <tp@euro-linux.com>

script_dir=$(dirname $(readlink -f $0))
cd "$script_dir" || exit 1

echo "Setting LANG to en_US.UTF-8"
export LANG="en_US.UTF-8"

# Run the tests supplied as parameters or all available tests if no parameters
# have been provided
if [ "$#" -gt 0 ]; then
  tests=( "$@" )
else
  mapfile -t tests < <(ls ./EL-core-functional-tests/tests/)
fi

# Get the tests we want to skip in the box the script runs in.
echo "Determining tests to skip based on the box' hostname..."
declare -a tests_to_skip
eval "$(grep -E "\#\ $HOSTNAME" skipped_tests.txt)"
echo "Tests that will be skipped for $HOSTNAME: ${tests_to_skip[*]}"

# Run the tests!
cd "/vagrant/tests/EL-core-functional-tests/" || exit

for test in "${tests[@]}" ; do
  if [[ "${tests_to_skip[*]}" =~ ${test} ]]; then
      echo "Skipping test $test..."
  else
      echo "Running test $test..."
      runtests_result="PASS"
      sudo timeout 5m ./runtests.sh "$test" || runtests_result="FAIL"
      echo "Result of $test: $runtests_result"
  fi
done
