#!/bin/bash 
# name: remove_kernels.sh
#
# description: remove kernels and kernel-related packages from the distro the
# migration has been performed from
#
# Copyright 2021 EuroLinux, Inc.
# Author: Tomasz Podsiadły <tp@euro-linux.com>

usage() {
    echo "Usage: ${0##*/} [OPTIONS]

OPTIONS
-a 1/2/3    The number of the answer on what to remove:
            1 - dry-run, just list the packages that would be removed and
              don't touch them
  (default) 2 - all non-EuroLinux kernels and related packages including
              those from unofficial sources.
            3 - kernels and related packages only provided by the distro
              that has been migrated to EuroLinux.
-h          Display this help and exit"
    exit 1
}

beginning_preparations() {
  set -e
  github_url="https://github.com/EuroLinux/eurolinux-migration-scripts"
  declare -i answer
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
  mapfile -t installed_kernel_packages < <(rpm -qa --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}|%{VENDOR}|%{PACKAGER}\n' kernel kernel* | sed 's@\ @\_@g')
  latest_eurolinux_kernel_package="$(printf -- '%s\n' "${installed_kernel_packages[@]}" | grep -E 'EuroLinux|Scientific' | grep '^kernel-[0-9]\.[0-9]' | sort -r | head -n 1 | cut -d '|' -f 1)"
  if [ -z "$latest_eurolinux_kernel_package" ]; then
    exit_message "Could not determine if a migration was successful - could 
not find a package that provides an EuroLinux kernel."
  fi
}

prepare_list_of_kernels_to_be_removed() {
  # Consider several scenarios such as non-EuroLinux kernels that come from
  # e.g.  ELRepo or other sources. What should be done with them is up to the
  # user to decide via an interactive answer.
  mapfile -t all_non_eurolinux_kernel_packages < \
    <(printf -- '%s\n' "${installed_kernel_packages[@]}" | grep -Ev 'EuroLinux|Scientific' | sed 's@\ @\_@g')
  mapfile -t migratable_distros_kernel_packages < \
    <(printf -- '%s\n' ${all_non_eurolinux_kernel_packages[@]} | grep -E 'Red.Hat|CentOS|Oracle|Rocky|Alma' | sed 's@\ @\_@g')
  echo "The following non-EuroLinux kernel packages are still remaining:"
  [ ${#migratable_distros_kernel_packages[@]} -eq 0 ] && echo 'none, nothing to do, exiting.' && exit 0
  printf -- '%s\n' "${all_non_eurolinux_kernel_packages[@]}"
  echo "---"
  if [ ${#migratable_distros_kernel_packages[@]} -gt 0 ]; then
    echo "Among which these come from the systems the script supports migration from:"
    printf -- '%s\n' "${migratable_distros_kernel_packages[@]}"
    echo "---"
  fi

  if [ -z "$answer" ]; then
    echo "The answer hasn't been specified - proceeding by removing all non-EuroLinux kernels and related packagaes."
    answer=2
  else
    echo "The desired operation has been specified with \"${0##*/} -a $answer\", proceeding..."
  fi

  case "$answer" in
    1) echo "Leaving all kernel packages as they are."
       exit 0
       ;;
    2) printf -- '%s\n' "${all_non_eurolinux_kernel_packages[@]%%|*}" > /root/kernel_packages_to_remove.txt ;;
    3) if [ ${#migratable_distros_kernel_packages[@]} -gt 0 ]; then
         printf -- '%s\n' "${migratable_distros_kernel_packages[@]%%|*}" > /root/kernel_packages_to_remove.txt
       else
         exit_message "Answer $answer not applicable since there are no kernel packages provided by a distro that has been migrated to EuroLinux."
       fi
       ;;
    *) exit_message "Unknown Answer: $answer."
  esac
}

remove_old_rescue_kernels() {
  # Only applicable to EL8 right now. To be ported to EL7 if needed.
  echo "Removing old 'rescue' kernels and bootloader entries..."
  find /boot -name '*vmlinuz*rescue*' -exec rm -f {} + -exec grubby --remove-kernel={} \;

  # Generation of a new rescue kernel is not yet production-ready and thus commented out
  #kernel-install add "${latest_eurolinux_kernel_path##*/vmlinuz-}" "$latest_eurolinux_kernel_path"
}

set_latest_eurolinux_kernel() {
  # Determine the EuroLinux-branded kernel that is installed and set it as the
  # default one. The system shall be rebooted soon after and other kernels will
  # be removed only then - this is explained later on as a comment.
  latest_eurolinux_kernel_path="$(find /boot -name ${latest_eurolinux_kernel_package/kernel/vmlinuz})"
  grubby --set-default="${latest_eurolinux_kernel_path}"
}

update_grub() {
  # Update bootloader entries. Output to a symlink which always points to the
  # proper configuration file.
  printf "Updating the GRUB2 bootloader at: "
  [ -d /sys/firmware/efi ] && grub2_conf="/etc/grub2-efi.cfg" || grub2_conf="/etc/grub2.cfg"
  printf "$grub2_conf (symlinked to $(readlink $grub2_conf)).\n"
  grub2-mkconfig -o "$grub2_conf"
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
ExecStart=/bin/bash -c "cat /root/kernel_packages_to_remove.txt | xargs yum remove -y && [ -d /sys/firmware/efi ] && grub2-mkconfig -o /etc/grub2-efi.cfg || grub2-mkconfig -o /etc/grub2.cfg"
ExecStartPost=/bin/systemctl disable remove-non-eurolinux-kernels.service

[Install]
WantedBy=multi-user.target
EOF

  systemctl enable remove-non-eurolinux-kernels.service && \
    echo "Kernel removal will be performed on next system boot."
    echo "Additionally a GRUB2 update will be performed along with an automatic system reboot"
}

main() {
  beginning_preparations
  check_successful_migration
  prepare_list_of_kernels_to_be_removed
  remove_old_rescue_kernels
  set_latest_eurolinux_kernel
  update_grub
  prepare_systemd_service
}

while getopts "a:h" option; do
    case "$option" in
        a) answer="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

main
