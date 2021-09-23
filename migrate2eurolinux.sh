#!/bin/bash
# Initially based on Oracle's centos2ol script. Thus licensed under the Universal Permissive License v1.0
# Copyright (c) 2020, 2021 Oracle and/or its affiliates.
# Copyright (c) 2021 EuroLinux

beginning_preparations() {
  set -e
  unset CDPATH
  declare el_euroman_user
  declare el_euroman_password

  github_url="https://github.com/EuroLinux/eurolinux-migration-scripts"
  # These are all the packages we need to remove. Some may not reside in
  # this array since they'll be swapped later on once EuroLinux
  # repositories have been added.
  bad_packages=(almalinux-backgrounds almalinux-backgrounds-extras almalinux-indexhtml almalinux-logos almalinux-release almalinux-release-opennebula-addons centos-backgrounds centos-gpg-keys centos-indexhtml centos-linux-release centos-linux-repos centos-logos centos-release centos-release-advanced-virtualization centos-release-ansible26 centos-release-ansible-27 centos-release-ansible-28 centos-release-ansible-29 centos-release-azure centos-release-ceph-jewel centos-release-ceph-luminous centos-release-ceph-nautilus centos-release-ceph-octopus centos-release-configmanagement centos-release-cr centos-release-dotnet centos-release-fdio centos-release-gluster40 centos-release-gluster41 centos-release-gluster5 centos-release-gluster6 centos-release-gluster7 centos-release-gluster8 centos-release-gluster-legacy centos-release-messaging centos-release-nfs-ganesha28 centos-release-nfs-ganesha30 centos-release-nfv-common centos-release-nfv-openvswitch centos-release-openshift-origin centos-release-openstack-queens centos-release-openstack-rocky centos-release-openstack-stein centos-release-openstack-train centos-release-openstack-ussuri centos-release-opstools centos-release-ovirt42 centos-release-ovirt43 centos-release-ovirt44 centos-release-paas-common centos-release-qemu-ev centos-release-qpid-proton centos-release-rabbitmq-38 centos-release-samba411 centos-release-samba412 centos-release-scl centos-release-scl-rh centos-release-storage-common centos-release-virt-common centos-release-xen centos-release-xen-410 centos-release-xen-412 centos-release-xen-46 centos-release-xen-48 centos-release-xen-common desktop-backgrounds-basic insights-client libreport-centos libreport-plugin-mantisbt libreport-plugin-rhtsupport libreport-rhel libreport-rhel-anaconda-bugzilla libreport-rhel-bugzilla libzstd oracle-backgrounds oracle-epel-release-el8 oracle-indexhtml oraclelinux-release oraclelinux-release-el7 oraclelinux-release-el8 oracle-logos python3-syspurpose python-oauth redhat-backgrounds Red_Hat_Enterprise_Linux-Release_Notes-7-en-US redhat-indexhtml redhat-logos redhat-release redhat-release-eula redhat-release-server redhat-support-lib-python redhat-support-tool rocky-backgrounds rocky-gpg-keys rocky-indexhtml rocky-logos rocky-obsolete-packages rocky-release rocky-repos sl-logos uname26 yum-conf-extras yum-conf-repos)
}

usage() {
    echo "Usage: ${0##*/} [OPTIONS]"
    echo
    echo "OPTIONS"
    echo "-f      Skip warning messages"
    echo "-h      Display this help and exit"
    echo
    echo "OPTIONS applicable to Enterprise Linux 7 or older"
    echo "-u      Your EuroMan username (usually an email address)"
    echo "-p      Your EuroMan password"
    exit 1
}

warning_message() {
  if [ "$skip_warning" != "true" ]; then
    echo "This script will migrate your existing Enterprise Linux system to EuroLinux. Extra precautions have been arranged but there's always the risk of something going wrong in the process and users are always recommended to make a backup."
    echo "Do you want to continue? Type YES in uppercase if that's the case."
    read answer
    if [ "$answer" != "YES" ]; then
      exit_message "Confirmation denied since an answear other than 'YES' was provided, exiting."
    fi
  fi
}

dep_check() {
  if ! command -v "$1"; then
      exit_message "'${1}' command not found. Please install or add it to your PATH and try again."
  fi
}

exit_message() {
  echo "$1"
  echo "For assistance, please open an issue via GitHub: ${github_url}."
  exit 1
}

final_failure() {
  exit_message "An error occurred while attempting to switch this system to EuroLinux and it may be in an unstable/unbootable state. To avoid further issues, the script has terminated."
}

generate_rpms_info() {
  # $1 - before/after
  echo "Creating a list of RPMs installed $1 the switch"
  rpm -qa --qf "%{NAME}-%{EPOCH}:%{VERSION}-%{RELEASE}.%{ARCH}|%{INSTALLTIME}|%{VENDOR}|%{BUILDTIME}|%{BUILDHOST}|%{SOURCERPM}|%{LICENSE}|%{PACKAGER}\n" | sed 's/(none)://g' | sort > "/var/tmp/$(hostname)-rpms-list-$1.log"
  echo "Verifying RPMs installed $1 the switch against RPM database"
  rpm -Va | sort -k3 > "/var/tmp/$(hostname)-rpms-verified-$1.log"
}

check_root() {
  if [ "$(id -u)" -ne 0 ]; then
      exit_message "You must run this script as root.
  Try running 'su -c ${0}'."
  fi
}

check_required_packages() {
  echo "Checking for required packages..."
  for pkg in rpm yum curl; do
      dep_check "${pkg}"
  done
}

check_distro() {
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

verify_rpms_before_migration() {
  echo "Collecting information about RPMs before the switch..."
  generate_rpms_info before
}

check_supported_releases() {
  case "${old_release}" in
    redhat-release*) ;;
    centos-release* | centos-linux-release*) ;;
    sl-release*) ;;
    almalinux-release*) ;;
    rocky-release*) ;;
    oracle-release*|oraclelinux-release*|enterprise-release*) ;;
    el-release*|eurolinux-release*)
      exit_message "You appear to be already running EuroLinux."
      ;;
    *) exit_message "You appear to be running an unsupported distribution: ${old_release}." ;;
  esac
}

prepare_pre_migration_environment() {
  os_version=$(rpm -q "${old_release}" --qf "%{version}")
  major_os_version=${os_version:0:1}
  base_packages=(basesystem initscripts el-logos)
  case "$os_version" in
    7* | 8*)
      new_releases=(el-release)
      base_packages=("${base_packages[@]}" plymouth grub2 grubby)
      ;;
    *) exit_message "You appear to be running an unsupported OS version: ${os_version}." ;;
  esac
  if [[ "$old_release" =~ oraclelinux-release-(el)?[78] ]] ; then
    echo "Oracle Linux detected - unprotecting systemd temporarily for distro-sync to succeed..."
    mv /etc/yum/protected.d/systemd.conf /etc/yum/protected.d/systemd.conf.bak
  fi
}

check_yum_lock() {
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

check_systemwide_python() {
  echo "Checking for required python packages..."
  case "$os_version" in
    8*)
      dep_check /usr/libexec/platform-python
      ;;
    *)
      dep_check python2
      ;;
  esac
}

switch_module_branding() {
  if [[ "$os_version" =~ 8.* ]]; then
    echo "Identifying dnf modules that are enabled..."
    mapfile -t modules_enabled < <(dnf module list --enabled | grep -E 'ol8?\ \[' | awk '{print $1}')
    if [[ "${modules_enabled[*]}" ]]; then
      unknown_modules=()
      for module in "${modules_enabled[@]}"; do
        case ${module} in
          container-tools|go-toolset|jmc|llvm-toolset|rust-toolset|virt)
            ;;
          *)
            unknown_modules+=("${module}")
            ;;
        esac
      done
      if [ ${#unknown_modules[@]} -gt 0 ]; then
        echo "This tool is unable to automatically switch module(s) '${unknown_modules[*]}' from an Oracle 'ol' stream to
an EuroLinux equivalent. Do you want to continue and resolve it manually?
You may want select No to stop and raise an issue on ${github_url} for advice."
        select yn in "Yes" "No"; do
          case $yn in
            Yes )
              break
              ;;
            No )
              echo "Unsure how to switch module(s) '${unknown_modules[*]}'. Exiting as requested"
              exit 1
              ;;
          esac
        done
      fi
    fi
  fi
}

find_repos_directory() {
  echo "Finding your repository directory..."
  case "$os_version" in
    8*)
      reposdir=$(/usr/libexec/platform-python -c "
import dnf
import os

dir = dnf.Base().conf.get_reposdir
if os.path.isdir(dir):
  print(dir)
      ")
      ;;
    *)
      reposdir=$(python2 -c "
import yum
import os

for dir in yum.YumBase().doConfigSetup(init_plugins=False).reposdir:
  if os.path.isdir(dir):
    print dir
    break
      ")
      ;;
  esac
  if [ -z "${reposdir}" ]; then
    exit_message "Could not locate your repository directory."
  fi
}

find_enabled_repos() {
  echo "Learning which repositories are enabled..."
  case "$os_version" in
    8*)
      enabled_repos=$(/usr/libexec/platform-python -c "
import dnf

base = dnf.Base()
base.read_all_repos()
for repo in base.repos.iter_enabled():
  print(repo.id)
      ")
      ;;
    *)
      enabled_repos=$(python2 -c "
import yum

base = yum.YumBase()
base.doConfigSetup(init_plugins=False)
for repo in base.repos.listEnabled():
  print repo
      ")
      ;;
  esac
  echo -e "Repositories enabled before update include:\n${enabled_repos}"
}

grab_gpg_keys() {
  echo "Grabbing EuroLinux GPG keys..."
  case "$os_version" in
    7* | 8*)
      curl --silent "https://fbi.cdn.euro-linux.com/security/RPM-GPG-KEY-eurolinux$major_os_version" > "/etc/pki/rpm-gpg/RPM-GPG-KEY-eurolinux$major_os_version"
      ;;
    *) exit_message "You appear to be running an unsupported OS version: ${os_version}." ;;
  esac
}

get_yumdownloader() {
  echo "Looking for yumdownloader..."
  if ! command -v yumdownloader; then
  yum -y install yum-utils || true
  dep_check yumdownloader
  fi
}

create_temp_el_repo() {
  cd "$reposdir"
  echo "Creating a temporary repo file for migration..."
  case "$os_version" in
    8*)
      cat > "switch-to-eurolinux.repo" <<-'EOF'
[certify-baseos]
name = EuroLinux certify BaseOS
baseurl=https://fbi.cdn.euro-linux.com/dist/eurolinux/server/8/$basearch/certify-BaseOS/os
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-eurolinux8
skip_if_unavailable=1

[certify-appstream]
name = EuroLinux certify AppStream
baseurl=https://fbi.cdn.euro-linux.com/dist/eurolinux/server/8/$basearch/certify-AppStream/os
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-eurolinux8
skip_if_unavailable=1

[certify-powertools]
name = EuroLinux certify PowerTools
baseurl=https://fbi.cdn.euro-linux.com/dist/eurolinux/server/8/$basearch/certify-PowerTools/os
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-eurolinux8
skip_if_unavailable=1

EOF
      ;;
    7*)
      cat > "switch-to-eurolinux.repo" <<-'EOF'
[euroman_tmp]
name=euroman_tmp
baseurl=https://elupdate.euro-linux.com/pub/enterprise-7/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-eurolinux7

[fbi]
name = Free Base Image Repo
baseurl=https://fbi.cdn.euro-linux.com/dist/eurolinux/server/7/$basearch/fbi/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-eurolinux7

EOF
      ;;
    *) exit_message "You appear to be running an unsupported OS version: ${os_version}." ;;
  esac
}

register_to_euroman() {
  echo "Registering to EuroMan if applicable..."
  case "$os_version" in
    8*) 
      echo "EuroLinux 8 is Open Core, not registering."
      ;;
    *)
      if [ -z ${el_euroman_user+x} ]; then 
        echo "Please provide your EuroMan username: "
        read el_euroman_user
      fi
      if [ -z ${el_euroman_password+x} ]; then
        echo "Please provide your EuroMan password: "
        read el_euroman_password
      fi
      echo "Installing EuroMan-related tools..."
      yum install -y python-hwdata rhn-client-tools rhn-check yum-rhn-plugin yum-utils rhnlib rhn-setup rhnsd
      yum update -y  python-hwdata rhn-client-tools rhn-check yum-rhn-plugin yum-utils rhnlib rhn-setup rhnsd
      echo "Determining el_org_id based on your registration name & password..."
      el_org_id=$(python2 -c "
import xmlrpclib
import rhn.transports 
import ssl
import sys

EUROMAN_URL = 'https://xmlrpc.elupdate.euro-linux.com/rpc/api'
EUROMAN_FQDN = 'elupdate.euro-linux.com'

context = hasattr(ssl, '_create_unverified_context') and ssl._create_unverified_context() or None
client = None
try: # EuroLinux7
  client = xmlrpclib.ServerProxy(EUROMAN_URL,transport=xmlrpclib.SafeTransport(use_datetime=True, context=context))
except Exception as e:
  pass
if client is None: # EuroLinux6
   try:
     client = xmlrpclib.ServerProxy(EUROMAN_URL,transport=xmlrpclib.SafeTransport(use_datetime=True, context=context))
   except:
     client = xmlrpclib.ServerProxy(EUROMAN_URL)

try:
  key = client.auth.login(\"$el_euroman_user\",\"$el_euroman_password\")
except xmlrpclib.Fault as e:
  print 'There was a problem during authentication! Here is the error message:'
  print 'Error code:', e.faultCode
  print 'Error string:', e.faultString
  sys.exit(0)

my_org = client.user.getDetails(key, \"$el_euroman_user\")['org_id']
print(my_org)
      ")
      echo "Trying to register system with rhnreg_ks..."
      rhnreg_ks --force --username "$el_euroman_user" --password "$el_euroman_password" --activationkey="$el_org_id-default-$major_os_version"
      ;;
  esac
}

disable_distro_repos() {
  cd "$reposdir"

  cd "$(mktemp -d)"
  trap final_failure ERR

  # Most distros keep their /etc/yum.repos.d content in the -release rpm. Some do not and here are the tweaks for their more complex solutions...
  case "$old_release" in
    centos-release-8.*|centos-linux-release-8.*)
      old_release=$(rpm -qa centos*repos) ;;
    rocky-release*)
      old_release=$(rpm -qa rocky*repos) ;;
    oraclelinux-release-8.*)
      old_release=$(rpm -qa oraclelinux-release-el8*) ;;
    oraclelinux-release-7.*)
      old_release=$(rpm -qa oraclelinux-release-el7*) ;;
    *) : ;;
  esac

  echo "Backing up and removing old repository files..."

  # ... this one should apply to any Enterprise Linux except RHEL:
  echo "Identify repo files from the base OS..."
  if [[ "$old_release" =~ redhat-release ]]; then
    echo "RHEL detected and repo files are not provided by 'release' package."
  else
    rpm -ql "$old_release" | grep '\.repo$' > repo_files
  fi

  # ... and the complex solutions continue with these checks:
  if [ "$(rpm -qa "centos-release*" | wc -l)" -gt 0 ] ; then
  echo "Identify repo files from 'CentOS extras'..."
    rpm -qla "centos-release*" | grep '\.repo$' >> repo_files
  fi

  if [ "$(rpm -qa "yum-conf-*" | wc -l)" -gt 0 ] ; then
  echo "Identify repo files from 'Scientific Linux extras'..."
    rpm -qla "yum-conf-*" | grep '\.repo$' >> repo_files
  fi

  # ... finally we should have all the old repos disabled!
  while read -r repo; do
    if [ -f "$repo" ]; then
      cat - "$repo" > "$repo".disabled <<EOF
# This is a yum repository file that was disabled by
# ${0##*/}, a script to convert an Enterprise Linux variant to EuroLinux.
# Please see $github_url for more information.

EOF
      tmpfile=$(mktemp repo.XXXXX)
      echo "$repo" | cat - "$repo" > "$tmpfile"
      rm "$repo"
    fi
  done < repo_files
  trap - ERR
}

remove_centos_yum_branding() {
  echo "Removing CentOS-specific yum configuration from /etc/yum.conf if applicable..."
  sed -i.bak -e 's/^distroverpkg/#&/g' -e 's/^bugtracker_url/#&/g' /etc/yum.conf
}

get_el_release() {
  echo "Downloading EuroLinux release package..."
  if ! yumdownloader "${new_releases[@]}"; then
    {
      echo "Could not download the following packages:"
      echo "${new_releases[@]}"
      echo
      echo "Are you behind a proxy? If so, make sure the 'http_proxy' environment"
      echo "variable is set with your proxy address."
    }
    final_failure
  fi
}

fix_oracle_shenanigans() {
  # Several packages in Oracle Linux have a different naming convention. These
  # are incompatible with other Enterprise Linuxes and treated as newer
  # versions by package managers. For a migration we need to 'downgrade' them
  # to EuroLinux equivalents once EuroLinux repositories have been added.
  #
  # Some Oracle Linux exclusive packages with no equivalents will be removed
  # as well.
  if [[ "$(rpm -qa 'oraclelinux-release-el7*')" ]]; then
    yum downgrade -y $(for suffixable in $(rpm -qa | egrep "\.0\.[1-9]\.el7") ; do rpm -q $suffixable --qf '%{NAME}\n' ; done)
    yum downgrade -y $(rpm -qa --qf '%{NAME}:%{VENDOR}\n' | grep -i oracle | cut -d':' -f 1)
    yum remove -y uname26 libzstd
  fi
}

install_el_base() {
  echo "Installing base packages for EuroLinux..."
  if ! yum shell -y <<EOF
  remove ${bad_packages[@]}
  install ${base_packages[@]}
  run
EOF
  then
    exit_message "Could not install base packages. Run 'yum distro-sync' to manually install them."
  fi
}

update_initrd() {
  if [ -x /usr/libexec/plymouth/plymouth-update-initrd ]; then
    echo "Updating initrd..."
    /usr/libexec/plymouth/plymouth-update-initrd
  fi
}

el_distro_sync() {
  echo "Switch successful. Syncing with EuroLinux repositories..."
  if ! yum -y distro-sync; then
    exit_message "Could not automatically sync with EuroLinux repositories.
  Check the output of 'yum distro-sync' to manually resolve the issue."
  fi
}

debrand_modules() {
  case "$os_version" in
    8*)
      # There are a few dnf modules that are named after the distribution
      #  for each steam named 'ol' or 'ol8' perform a module reset and install
      if [[ "${modules_enabled[*]}" ]]; then
        for module in "${modules_enabled[@]}"; do
          dnf module reset -y "${module}"
          case ${module} in
          container-tools|go-toolset|jmc|llvm-toolset|rust-toolset|virt)
            dnf module install -y "${module}"
            ;;
          *)
            echo "Unsure how to transform module ${module}"
            ;;
          esac
        done
        dnf --assumeyes --disablerepo "*" --enablerepo "certify*" update
      fi
      ;;
    *) : ;;
  esac
}

swap_rpms() {
  case "$os_version" in
    8*)
      if [[ "$(rpm -qa '*-release' | grep -v 'el-release')" ]]; then
        yum swap -y "*-release" "el-release"
      fi

      if [[ "$(rpm -qa '*-logos' | grep -v 'el-logos')" ]]; then
        yum swap -y "*-logos" "el-logos"
      fi
      ;;
    7*)
      if [[ "$(rpm -qa '*-release')" ]] && [[ ! "$(rpm -qa 'oraclelinux-release-el7*')" ]]; then
        yum swap -y "*-release" "el-release"
      fi

      if [[ "$(rpm -qa '*-logos')" ]]; then
        yum swap -y "*-logos" "el-logos"
      fi
      ;;
    *) : ;;
  esac

  if [[ "$(rpm -qa '*-logos-ipa')" ]]; then
    yum swap -y "*-logos-ipa" "el-logos-ipa"
  fi

  if [[ "$(rpm -qa '*-logos-httpd')" ]]; then
    yum swap -y "*-logos-httpd" "el-logos-httpd"
  fi
}

reinstall_all_rpms() {
  echo "Reinstalling all RPMs..."
  yum reinstall -y \*
  mapfile -t non_eurolinux_rpms < <(rpm -qa --qf "%{NAME}-%{VERSION}-%{RELEASE}|%{VENDOR}|%{PACKAGER}\n" |grep -Ev 'EuroLinux|Scientific') # Several packages are branded as from Scientific Linux and that's the expected behavior
  if [[ -n "${non_eurolinux_rpms[*]}" ]]; then
    echo "The following non-EuroLinux RPMs are installed on the system:"
    printf '\t%s\n' "${non_eurolinux_rpms[@]}"
    echo "This may be expected of your environment and does not necessarily indicate a problem."
    echo "If a large number of RPMs from other vendors are included and you're unsure why please open an issue on ${github_url}"
  fi
}

update_grub() {
  case "$os_version" in
    7* | 8*)
      echo "Updating the GRUB2 bootloader."
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
    ;;
  esac
}

remove_cache() {
  echo "Removing yum cache..."
  rm -rf /var/cache/{yum,dnf}
  echo "Removing temporary repo..."
  rm -f "${reposdir}/switch-to-eurolinux.repo"

  if [[ "$old_release" =~ oraclelinux-release-(el)?[78] ]] ; then
    echo "Protecting systemd just as it was initially set up in Oracle Linux..."
    mv /etc/yum/protected.d/systemd.conf.bak /etc/yum/protected.d/systemd.conf
  fi
}

verify_generated_rpms_info() {
  echo "Collecting information about RPMs after the switch..."
  generate_rpms_info after
  echo "Review the output of following files:"
  find /var/tmp/ -type f -name "$(hostname)-rpms-*.log"
}

congratulations() {
  echo "Switch complete."
  echo "EuroLinux recommends rebooting this system."
}

main() {
  warning_message
  check_root
  beginning_preparations
  check_required_packages
  check_distro
  verify_rpms_before_migration
  check_supported_releases
  prepare_pre_migration_environment
  check_yum_lock
  check_systemwide_python
  switch_module_branding
  find_repos_directory
  find_enabled_repos
  grab_gpg_keys
  get_yumdownloader
  create_temp_el_repo
  register_to_euroman
  disable_distro_repos
  remove_centos_yum_branding
  get_el_release
  install_el_base
  update_initrd
  el_distro_sync
  debrand_modules
  swap_rpms
  reinstall_all_rpms
  fix_oracle_shenanigans
  update_grub
  remove_cache
  verify_generated_rpms_info
  congratulations
}

while getopts "fhp:u:" option; do
    case "$option" in
        f) skip_warning="true" ;;
        h) usage ;;
        p) el_euroman_password="$OPTARG" ;;
        u) el_euroman_user="$OPTARG" ;;
        *) usage ;;
    esac
done
main

