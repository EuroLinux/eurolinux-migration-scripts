#!/bin/bash -x
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
  mapfile -t installed_kernel_packages < <(rpm -qa --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}|%{VENDOR}|%{PACKAGER}\n' kernel)
  if [ ! $(grep -E 'EuroLinux|Scientific' <<< "${installed_kernel_packages[@]}" ) ]; then
    exit_message "Could not find a package that provides an EuroLinux kernel."
  fi
}

set_latest_eurolinux_kernel() {
  latest_eurolinux_kernel_package="$(grep -E 'EuroLinux|Scientific' <<< "${installed_kernel_packages[@]}" | sort -r | head -n 1)"
  latest_eurolinux_kernel_path="$(find /boot -name ${latest_eurolinux_kernel_package/kernel/vmlinuz})"
  grubby --set-default="${latest_eurolinux_kernel_path}"
}

update_grub() {
  # Cover all distros and versions bootloader entries.
  # This snippet has been copied from migrate2eurolinux.sh and it's about to
  # be brainstormed what location/responsibility (script) suits it better,
  # TODO: more EFI entries?
  echo "Updating the GRUB2 bootloader..."
  if [ -d /sys/firmware/efi ]; then
    if [ -d /boot/efi/EFI/almalinux ]; then
      grub2-mkconfig -o /boot/efi/EFI/almalinux/grub.cfg
    elif [ -d /boot/efi/EFI/centos ]; then
      grub2-mkconfig -o /boot/efi/EFI/centos/grub.cfg
    else
      grub2-mkconfig -o /boot/efi/EFI/redhat/grub.cfg
    fi
  else
    grub2-mkconfig -o /boot/grub2/grub.cfg
  fi
}

prepare_list_of_kernels_to_be_removed() {
  # Consider several scenarios such non-EuroLinux kernels that come from e.g.
  # ELRepo or other sources. What should be done with them is up to the user
  # to decide via an answer or a parameter.
  mapfile -t all_non_eurolinux_kernel_packages < <(grep -Ev 'EuroLinux|Scientific' <<< "${installed_kernel_packages[@]}")
  mapfile -t migratable_distros_kernel_packages < <(grep -E 'Red Hat|CentOS|Oracle|Rocky|Alma' <<< ${all_non_eurolinux_kernel_packages[@]})
  echo "The following non-EuroLinux kernel packages are still remaining:
${all_non_eurolinux_kernel_packages[@]}
---"
  if [ ${#migratable_distros_kernel_packages[@]} -gt 0 ]; then
    echo "Among which these come from the distributions the script supports migration from:
${migratable_distros_kernel_packages[@]}
---"
  fi

  echo "What should the script do:
1. leave all non-EuroLinux kernel packages as they are
2. remove all non-EuroLinux kernel packages"
  if [ ${#migratable_distros_kernel_packages[@]} -gt 0 ]; then
    echo "3. remove only the kernel packages that come from migratable distros"
  fi
  echo "Please type the number of the desired operation: "
  read answer

  case "$answer" in
    1) 
       echo "Leaving all kernel packages as they are."
       exit 0
       ;;
    2) echo "${all_non_eurolinux_kernel_packages[@]}" > /root/kernel_packages_to_remove.txt ;;
    3) 
       if [ ${#migratable_distros_kernel_packages[@]} -gt 0 ]; then
         echo "${migratable_distros_kernel_packages[@]}" > /root/kernel_packages_to_remove.txt ;;
       else
         exit_message "Unknown answer: $answer."
       fi
    *) exit_message "Unknown answer: $answer."
  esac

}


main() {
  beginning_preparations
  check_successful_migration
  set_latest_eurolinux_kernel
  update_grub
  prepare_list_of_kernels_to_be_removed
}

main
