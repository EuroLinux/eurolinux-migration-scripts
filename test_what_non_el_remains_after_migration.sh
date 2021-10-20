#!/bin/bash

echo "Performing post-migration checks..."
mapfile -t non_eurolinux_rpms_from_yum_list < <(yum list installed | sed '/^[^@]*$/{N;s/\n//}' | grep -Ev '@el-server-|@euroman|@fbi|@certify' | grep '@' | cut -d' ' -f 1 | cut -d'.' -f 1)
mapfile -t non_eurolinux_rpms_and_metadata < <(rpm -qa --qf "%{NEVRA}|%{VENDOR}|%{PACKAGER}\n" ${non_eurolinux_rpms_from_yum_list[*]} | grep -Ev 'EuroLinux|Scientific') 
if [[ -n "${non_eurolinux_rpms_and_metadata[*]}" ]]; then
  echo "The following non-EuroLinux RPMs are installed on the system:"
  printf '\t%s\n' "${non_eurolinux_rpms_and_metadata[@]}"
  exit 1
fi
echo "Success - no non-EuroLinux RPMs are installed on the system."
exit 0
