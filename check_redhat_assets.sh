#!/bin/bash
# name: check_redhat_assets.sh
#
# description: create lists of checksummed files for removal after
# migrating from RHEL to EuroLinux
#
# Copyright 2021 EuroLinux, Inc.
# Author: Tomasz Podsiadły <tp@euro-linux.com>

set -euo pipefail

usage() {
echo "Usage: ${0##*/} [ARGUMENT]

ARGUMENTS
-b        Create list with Red Hat-provided files and
          their checksums (before migration)

-a        Check what assets remained after migration
          and remove them"
}

# Search for all the files the installed RPMs provide.
# This can be modified to look only at certain assets the `rpm` command
# allows, e.g. --configfiles or --docfiles.

# Note: the script does not attempt to check if a certain action is attemped
# on a migrated/non-migrated system or handle running with both -a and -b
# provided. This is done on purpose.

before_migration() {
  rpm -qa --qf '%{nevra}@%{vendor}\n' | grep -E 'Red Hat' \
    > all_redhat_packages.txt || \
  ( echo "No Red Hat packages found, exiting" && exit 0 )

  cut -d'@' -f1 < all_redhat_packages.txt \
  | xargs rpm -ql --noconfig > all_redhat_assets.txt

  # redhat-branded images and text assets
  grep -E '^redhat|^Red' "all_redhat_packages.txt" | cut -d'@' -f1 \
    | xargs rpm -ql --noconfig | grep -Ei 'fedora.logo|red' \
    | while IFS= read -r file; do \
        [ -f "$file" ] && printf '%s\n' "$file" ; \
      done > assets_to_check.txt

  xargs $sum < assets_to_check.txt > assets_checked_before_migration.txt
}

after_migration() {
  # It's pointless to perform any checks if the previous system did not
  # contain any Red Hat packages, that is if the system was an Enterprise
  # Linux variant other than RHEL.
  if [ $(wc -l all_redhat_packages.txt) -eq 0 ]; then
    echo "No Red Hat packages were listed before migration, exiting"
    exit 0
  fi 

  # Several assets will be removed after the migration and attempting to
  # checksum them will result in an error. So don't abort the script here.
  set +e
  xargs $sum < assets_to_check.txt > assets_checked_after_migration.txt
  set -e

  comm -12 <(sort "assets_checked_before_migration.txt") \
    <(sort "assets_checked_after_migration.txt") | cut -d' ' -f 3 \
    | grep -Ev '^/usr/share/doc/redhat-(release|menus)' | sort \
    > remaining_assets.txt \
    || (echo "Success - no Red Hat files found." && exit 0)

  if [ $(wc -l < remaining_assets.txt) -gt 0 ]; then
    echo "The following Red Hat files remain after the migration:"
    cat remaining_assets.txt
    echo "Removing them right now..."
    sudo xargs rm -f < remaining_assets.txt && echo "Assets removed."
  fi
}

sum="md5sum"

[[ ! $@ =~ ^\-.+ ]] && usage && exit 1
while getopts "ab" opt; do
  case $opt in
    a) after_migration
       ;;
    b) before_migration
       ;;
    *) usage
       exit 1
       ;;
  esac
done


