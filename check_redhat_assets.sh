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
  set +e
    rpm -qa --qf '%{nevra}@%{vendor}\n' | grep -E 'Red Hat' \
      > all_redhat_packages.txt
  set -e
  if [ ! -s "all_redhat_packages.txt" ] ; then
    echo "No Red Hat packages found on this system, exiting."
    exit 0
  fi

  cut -d'@' -f1 < all_redhat_packages.txt \
    | xargs rpm -ql --noconfig > all_redhat_assets.txt

  set +e
  # Red Hat-branded images and text assets
  grep -E 'insights|^redhat|^Red' "all_redhat_packages.txt" | cut -d'@' -f1 \
    | xargs rpm -ql --noconfig | grep -Ei 'fedora.logo|red|rhel' \
    | while IFS= read -r file; do \
        [ -f "$file" ] && printf '%s\n' "$file" ; \
      done > assets_to_check.txt
  set -e

  xargs $sum < assets_to_check.txt > assets_checked_before_migration.txt \
    && echo "$(wc -l < assets_to_check.txt) Red Hat assets found."
}

after_migration() {
  if [ ! -f "all_redhat_packages.txt" ] ; then
    echo "Run ${0##*/} -b (before migrating to EuroLinux) first."
  else
    if [ ! -s "all_redhat_packages.txt" ] ; then
      echo "It's pointless to perform any checks if the previous system did not
      contain any Red Hat packages, exiting."
      exit 0
    fi
  fi

  # Several assets will be removed after the migration and attempting to
  # checksum them will result in an error. So don't abort the script here.
  set +e
    xargs $sum < assets_to_check.txt > assets_checked_after_migration.txt
  set -e

  comm -12 <(sort "assets_checked_before_migration.txt") \
    <(sort "assets_checked_after_migration.txt") | cut -d' ' -f 3 \
    | grep -Ev '^/usr/share/doc/redhat-(release|menus)' | sort \
    > remaining_assets.txt

  if [ -s remaining_assets.txt ]; then
    echo "The following Red Hat files remain after the migration:"
    cat remaining_assets.txt
    echo "Removing them right now..."
    sudo xargs rm -f < remaining_assets.txt && echo "Assets removed."
  else
    echo "Success - no Red Hat files found after migrating to EuroLinux."
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


