#!/bin/bash 
# name: remove_kernels.sh
#
# description: remove kernels and GPG keys from the distro the migration has
# been performed from
#
# Copyright 2021 EuroLinux, Inc.
# Author: Tomasz Podsiadły <tp@euro-linux.com>

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
  # Consider a migration successful if the package "el-release" provides
  # /etc/redhat-release and the package "kernel" is EuroLinux-branded

  release_provider="$(rpm -q --whatprovides /etc/redhat-release)"
  if [[ ! "$release_provider" =~ ^el-release ]]; then
    exit_message "Could not determine if a migration was successful -
/etc/redhat-release is provided by the package \"$release_provider\" rather than 
el-release."
  fi

  # Query for the kernel-related packages and their metadata such as their
  # Vendor - such information will prove invaluable when determining, which of
  # them are made: by EuroLinux, by the Vendor of the distro a migration has
  # been performed from and by other third-party providers.
  # The result of the query will be stored in a Bash array named
  # installed_kernel_packages - though with a small twist of replacing spaces
  # with underscores since all whitespace characters will be treated as
  # delimiters later on.
  # Since earlier EuroLinux packages are branded as Scientific Linux, an
  # additional pattern is considered when looking up EuroLinux products. The
  # same pattern is used further in this script along with the replacement of
  # spaces with underscores.
  mapfile -t installed_kernel_packages < <(rpm -qa --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}|%{VENDOR}|%{PACKAGER}\n' kernel* | sed 's@\ @\_@g')
  latest_eurolinux_kernel_package="$(printf -- '%s\n' "${installed_kernel_packages[@]}" | grep -E 'EuroLinux|Scientific' | grep '^kernel-[0-9]\.[0-9]' | sort -r | head -n 1 | cut -d '|' -f 1)"
  if [ -z "$latest_eurolinux_kernel_package" ]; then
    exit_message "Could not determine if a migration was successful - could 
not find a package that provides an EuroLinux kernel."
  fi
}

set_latest_eurolinux_kernel() {
  # Determine the EuroLinux-branded kernel that is installed and set it as the
  # default one. The system shall be rebooted soon after and other kernels will
  # be removed only then - this is explained later on as a comment.
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
  mapfile -t all_non_eurolinux_kernel_packages < \
    <(printf -- '%s\n' "${installed_kernel_packages[@]}" | grep -Ev 'EuroLinux|Scientific' | sed 's@\ @\_@g')
  mapfile -t migratable_distros_kernel_packages < \
    <(printf -- '%s\n' ${all_non_eurolinux_kernel_packages[@]} | grep -E 'Red.Hat|CentOS|Oracle|Rocky|Alma' | sed 's@\ @\_@g')
  echo "The following non-EuroLinux kernel packages are still remaining:"
  printf -- '%s\n' "${all_non_eurolinux_kernel_packages[@]}"
  echo "---"
  if [ ${#migratable_distros_kernel_packages[@]} -gt 0 ]; then
    echo "Among which these come from the systems the script supports migration from:"
    printf -- '%s\n' "${migratable_distros_kernel_packages[@]}"
    echo "---"
  fi

  echo "What should the script do:"
  echo "1. leave all non-EuroLinux kernel packages as they are"
  echo "2. remove all non-EuroLinux kernel packages"
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
    2) printf -- '%s\n' "${all_non_eurolinux_kernel_packages[@]%%|*}" > /root/kernel_packages_to_remove.txt ;;
    3) 
       if [ ${#migratable_distros_kernel_packages[@]} -gt 0 ]; then
         printf -- '%s\n' "${migratable_distros_kernel_packages[@]%%|*}" > /root/kernel_packages_to_remove.txt
       else
         exit_message "Unknown answer: $answer."
       fi
       ;;
    *) exit_message "Unknown answer: $answer."
  esac
}

prepare_systemd_service() {
  # Once there's a list of the kernel-related packages the user wants to 
  # remove, create a systemd service that removes them and reboots the machine
  # if the removal succeeds. It will be enabled and run automatically on next
  # system boot.
  script_location="$(readlink -f $0)"
  cat > "/etc/systemd/system/remove-non-eurolinux-kernels.service" <<-EOF
[Unit]
Description=Remove non-EuroLinux kernels and kernel-related packages
SuccessAction=reboot

[Service]
Type=oneshot
ExecStart=/bin/bash -c "cat /root/kernel_packages_to_remove.txt | xargs yum remove -y && source $script_location && update_grub
ExecStartPost=/bin/systemctl disable remove-non-eurolinux-kernels.service

[Install]
WantedBy=multi-user.target
EOF

  systemctl enable remove-non-eurolinux-kernels.service && \
    echo "Kernel removal will be performed on next system boot."
    echo "Additionally a GRUB2 update will be performed along with an automatic system reboot"
    echo "Please don't remove this repository before the operations mentioned above have finished their job."
}

main() {
  beginning_preparations
  check_successful_migration
  set_latest_eurolinux_kernel
  update_grub
  prepare_list_of_kernels_to_be_removed
  prepare_systemd_service
}

main
