#!/bin/bash
# description: remove kernels and GPG keys from the distro the migration has
# been performed from
# Copyright (c) 2021 EuroLinux

# the algorithm:
# if there is  `el-release` and EuroLinux kernels are available ; then
#   use grubby to change to EuroLinux kernel as the default one
#   determine what to do with other kernels (those that the old distro provided
#     and other non-EuroLinux ones, e.g. from ELRepo) - either ask the user or
#     realize with parameters
#   systemctl enable "remove-non-eurolinux-kernels-on-next-boot.service"
#   systemd takes care of a reboot (so EuroLinux kernel will be in use),
#     removing the non-EuroLinux kernels and rebooting again for safety.
# fi

beginning_preparations() {
  set -e
  github_url="https://github.com/EuroLinux/eurolinux-migration-scripts"
  installed_kernel_packages="$(rpm -qa --qf '%{NAME}-%{VERSION}-%{RELEASE}|%{VENDOR}|%{PACKAGER}\n' kernel)"
}

exit_message() {
  # Wrap a generic message about a script error with EuroLinux' GitHub URL and
  # exit.
  echo "$1"
  echo "For assistance, please open an issue via GitHub: ${github_url}."
  exit 1
}

check_successful_migration() {
  release_provider="$(rpm -q --whatprovides /etc/redhat-release)"
  if [[ ! "$release_provider" =~ ^el-release ]]; then
    exit_message "Could not determine if a migration was successful -
/etc/redhat-release is provided by the package \"$release_provider\" rather than 
el-release."
  fi
  if [ ! $(grep -E 'EuroLinux|Scientific' <<< "$installed_kernel_packages" ) ]; then
    exit_message "Could not find a package that provides an EuroLinux kernel."
  fi
}

main() {
  beginning_preparations
  check_successful_migration
}

main
