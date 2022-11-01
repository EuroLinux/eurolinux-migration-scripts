#!/bin/bash
# Initially based on Oracle's centos2ol script. Thus licensed under the Universal Permissive License v1.0
# Copyright (c) 2020, 2021 Oracle and/or its affiliates.
# Copyright (c) 2021, 2022 EuroLinux

set -euo pipefail

exit_message() {
  # Wrap a generic message about a script error with EuroLinux' GitHub URL and
  # exit.
  echo "$1"
  echo "For assistance, please open an issue via GitHub: ${github_url}."
  exit 1
}

final_failure() {
  # A generalized exit message that will appear in case of a disastrous event.
  # Wrapped as a function since it will be used several times along with
  # `trap` on critical operations that are not easily revertible.
  exit_message "An error occurred while attempting to switch this system to EuroLinux and it may be in an unstable/unbootable state. To avoid further issues, the script has terminated."
}

check_root() {
  # The script must be ran with superuser privileges any way possible. You can
  # refer to the way described in README.md - just switch to the root account
  # and run with `bash migrate2eurolinux.sh`
  if [ "$(id -u)" -ne 0 ]; then
      exit_message "You must run this script as root."
  fi
}

check_distro() {
  # Determine the exact Enterprise Linux flavor installed now before a
  # migration took place. It has to be a one and only one specific match
  # against our supported distros list.
  # This function will check an RPM - your /etc/redhat-release provider. No
  # deep scans such as comparing mentions of other distros in package names,
  # configuration files, etc. will be checked - it may turn out in some
  # specific scenarios that distro X had packages branded as distro Y and Z
  # installed too - but if they are branded, they'll be removed as listed in
  # the bad_packages array.
  echo "Checking your distribution..."
  if ! old_release=$(rpm -q --whatprovides /etc/redhat-release); then
      exit_message "You appear to be running an unsupported distribution."
  fi

  if [ "$(echo "${old_release}" | wc -l)" -ne 1 ]; then
      exit_message "Could not determine your distribution because multiple
  packages are providing redhat-release:
  $old_release
  "
  fi
}

check_supported_releases() {
  # Our supported distros list mentioned earlier in check_distro() comments.
  # In here this check is generalized and the old_release variable may be
  # overridden later on once a more specific check is performed (this will be
  # explained later once this override is performed).
  case "${old_release}" in
    el-release*|eurolinux-release*) ;;
    redhat-release*) ;;
    almalinux-release*) ;;
    rocky-release*) ;;
    oracle-release*|oraclelinux-release*|enterprise-release*) ;;
    *) exit_message "You appear to be running an unsupported distribution: ${old_release}." ;;
  esac
}

check_yum_lock() {
  # Don't attempt to modify packages if there's an ongoing transaction.
  echo "Checking for yum lock..."
  if [ -f /var/run/yum.pid ]; then
    yum_lock_pid=$(cat /var/run/yum.pid)
    yum_lock_comm=$(cat "/proc/${yum_lock_pid}/comm")
    exit_message "Another app is currently holding the yum lock.
  The other application is: $yum_lock_comm
  Running as pid: $yum_lock_pid
  Run 'kill $yum_lock_pid' to stop it, then run this script again."
  fi
}

create_temp_el_repo() {
  cd "$reposdir"
  echo "Creating a temporary repo file for migration..."
  case "$os_version" in
    9*)
      cat > "eurolinux-desktop.repo" <<-EOF
[ELD]
name = EuroLinux Desktop
baseurl=https://fbi.cdn.euro-linux.com/dist/eurolinux/server/9/x86_64/Desktop/os/                                                  
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-eurolinux9
skip_if_unavailable=1

EOF
      ;;
    *) exit_message "You appear to be running an unsupported OS version: ${os_version}." ;;
  esac
}


install_el_base() {
  echo "Installing base packages for EuroLinux Desktop..."

  case "$os_version" in
    9*)
      dnf groupinstall "EuroLinux Desktop" -y
      ;;
    *) exit_message "You appear to be running an unsupported OS version: ${os_version}." ;;
  esac
}

congratulations() {
  echo "Switch almost complete. EuroLinux recommends rebooting this system."
}

main() {
  # All function calls.
  check_root
  check_distro
  check_supported_releases
  check_yum_lock
  create_temp_el_repo
  install_el_base
  congratulations
}

main

