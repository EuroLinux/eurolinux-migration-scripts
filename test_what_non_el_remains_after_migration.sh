#!/bin/bash

usage() {
    echo "Usage: ${0##*/} [OPTIONS]"
    echo
    echo "OPTIONS"
    echo "-t      Tolerate packages from 3rd-party repos, e.g. from EPEL"
    exit 1
}

tolerance=""

while getopts "t" option; do
    case "$option" in
        t) tolerance="tolerate-thirdparty" ;;
        *) usage ;;
    esac
done

echo "Performing post-migration checks..."
mapfile -t non_eurolinux_rpms_from_yum_list < <(yum list installed | sed '/^[^@]*$/{N;s/\n//}' | grep -Ev '@el-server-|@euroman|@fbi|@certify' | grep '@' | cut -d' ' -f 1 | cut -d'.' -f 1)
  mapfile -t non_eurolinux_rpms_and_metadata < <(rpm -qa --qf "%{NEVRA}|%{VENDOR}|%{PACKAGER}\n" ${non_eurolinux_rpms_from_yum_list[*]} | grep -Ev 'EuroLinux|Scientific' | sed 's@\ @\_@g' | grep -Ev '^(rhnlib|rhnsd).+\|\(none\)\|\(none\)$') 
if [[ -n "${non_eurolinux_rpms_and_metadata[*]}" ]]; then
  echo "The following non-EuroLinux RPMs are installed on the system:"
  printf '\t%s\n' "${non_eurolinux_rpms_and_metadata[@]}"
  if [ "$tolerance" == "tolerate-thirdparty" ]; then # Tolerate packages e.g. from EPEL, do not tolerate from AlmaLinux/CentOS/Oracle Linux/RHEL/Rocky Linux.
    echo "Checking for the presence of packages that come from the migratable systems..."
    bad_providers_pattern="\|AlmaLinux\||\|CentOS\||\|Oracle_America\||\|Red_Hat,_Inc\.\||\|Rocky\|"
    if grep -E "$bad_providers_pattern" <<< "${non_eurolinux_rpms_and_metadata[@]}" ; then
      echo "^^^ the packages above still remain - the migration is not considered as 100% complete. Please remove them manually."
      exit 1
    else
      echo "(none, the migration removed all packages from migratable systems)"
    fi
  else
    echo "Since the test requires that no thirdparty packages be present on the system, we consider this result as a failure."
    exit 1
  fi
fi
echo "Success - no non-EuroLinux RPMs are installed on the system."
exit 0

