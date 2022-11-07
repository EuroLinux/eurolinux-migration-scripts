#!/bin/bash
# Initially based on Oracle's centos2ol script. Thus licensed under the Universal Permissive License v1.0
# Copyright (c) 2020, 2021 Oracle and/or its affiliates.
# Copyright (c) 2021, 2022 EuroLinux

set -euo pipefail

# GLOBAL variables
answer=""
github_url="https://github.com/EuroLinux/eurolinux-migration-scripts"
preserve="true"
script_dir="$(dirname $(readlink -f $0))"
skip_warning=""
# These are all the packages we need to remove. Some may not reside in this
# array since they'll be swapped later on once EuroLinux repositories have been
# added.
bad_packages=(bcache-tools btrfs-progs centos-backgrounds centos-gpg-keys centos-indexhtml centos-linux-release centos-linux-repos centos-logos centos-release centos-release-advanced-virtualization centos-release-ansible26 centos-release-ansible-27 centos-release-ansible-28 centos-release-ansible-29 centos-release-azure centos-release-ceph-jewel centos-release-ceph-luminous centos-release-ceph-nautilus centos-release-ceph-octopus centos-release-configmanagement centos-release-cr centos-release-dotnet centos-release-fdio centos-release-gluster40 centos-release-gluster41 centos-release-gluster5 centos-release-gluster6 centos-release-gluster7 centos-release-gluster8 centos-release-gluster-legacy centos-release-messaging centos-release-nfs-ganesha28 centos-release-nfs-ganesha30 centos-release-nfv-common centos-release-nfv-openvswitch centos-release-openshift-origin centos-release-openstack-queens centos-release-openstack-rocky centos-release-openstack-stein centos-release-openstack-train centos-release-openstack-ussuri centos-release-opstools centos-release-ovirt42 centos-release-ovirt43 centos-release-ovirt44 centos-release-paas-common centos-release-qemu-ev centos-release-qpid-proton centos-release-rabbitmq-38 centos-release-samba411 centos-release-samba412 centos-release-scl centos-release-scl-rh centos-release-storage-common centos-release-virt-common centos-release-xen centos-release-xen-410 centos-release-xen-412 centos-release-xen-46 centos-release-xen-48 centos-release-xen-common centos-repos desktop-backgrounds-basic insights-client libreport-centos libreport-plugin-mantisbt libreport-plugin-rhtsupport libreport-rhel libreport-rhel-anaconda-bugzilla libreport-rhel-bugzilla libdtrace-ctf oracle-logos oraclelinux-release oraclelinux-release-6Server oraclelinux-release-notes-6Server python3-dnf-plugin-ulninfo python3-syspurpose python-oauth redhat-backgrounds Red_Hat_Enterprise_Linux-Release_Notes-7-en-US redhat-indexhtml redhat-logos redhat-release redhat-release-eula redhat-release-server redhat-support-lib-python redhat-support-tool sl-logos sl-release)


usage() {
    echo "Usage: ${0##*/} [OPTIONS]"
    echo
    echo "OPTIONS"
    echo "-f      Skip warning messages"
    echo "-h      Display this help and exit"
    echo "-w      Remove all detectable non-EuroLinux extras"
    echo "        (e.g. third-party repositories and backed-up .repo files)"
    echo "-u      Your EuroMan username (usually an email address)"
    echo "-p      Your EuroMan password"
    exit 1
}

warning_message() {
  # Display a warning message about backups unless running non-interactively
  # (assumed default behavior).
  if [ "$skip_warning" != "true" ]; then
    echo "This script will switch your existing Enterprise Linux 6 system repositories to EuroLinux 6's ones and remove that-system-specific packages like logos. Extra precautions have been arranged but there's always the risk of something going wrong in the process and users are always recommended to make a backup."
    echo "Do you want to continue? Type 'YES' if that's the case."
    read answer
    if [[ ! "$answer" =~ ^[Yy][Ee][Ss]$ ]]; then
      exit_message "Confirmation denied since an answer other than 'YES' was provided, exiting."
    fi
  fi
}

dep_check() {
  # Several utilities are needed for migrating. They may also differ in names
  # and versions between Enterprise Linux releases. Check if one of them ($1)
  # exists and exit if it doesn't.
  if ! command -v "$1"; then
      exit_message "'${1}' command not found. Please install or add it to your PATH and try again."
  fi
}

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

check_fips() {
  if [ "$(grep 'fips=1' /proc/cmdline)" ]; then
    exit_message "You appear to be running a system in FIPS mode, which is not supported for migration."
  fi
}

check_secureboot(){
  if grep -oq 'Secure Boot: enabled' <(bootctl 2>&1) ; then
    exit_message "You appear to be running a system with Secure Boot enabled, which is not yet supported for migration. Disable it first, then run the script again."
  fi
}

check_root() {
  # The script must be ran with superuser privileges any way possible. You can
  # refer to the way described in README.md - just switch to the root account
  # and run with `bash migrate2eurolinux.sh`
  if [ "$(id -u)" -ne 0 ]; then
      exit_message "You must run this script as root."
  fi
}

check_required_packages() {
  echo "Checking if the systems has the required packages installed..."
  for pkg in rpm yum curl; do
      dep_check "${pkg}"
  done
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
    redhat-release*) ;;
    centos-release* | centos-linux-release*) ;;
    sl-release*) ;;
    el-release*|eurolinux-release*) ;;
    *) exit_message "You appear to be running an unsupported distribution: ${old_release}." ;;
  esac
}

prepare_pre_migration_environment() {
  # Determine the exact details a distro exposes to perform a migration
  # successfully - some distros and their releases will need different
  # approaches and tweaks. Store these details for later use.
  os_version=$(rpm -q "${old_release}" --qf "%{version}")
  major_os_version=${os_version:0:1}
  base_packages=(basesystem grub2 grubby initscripts plymouth)
  case "${old_release}" in
    redhat-release*)
      echo "RHEL detected. Checking subscription status..."
      if [ "$(subscription-manager list --consumed | grep 'No consumed subscription pools were found' )"  ] ; then
        echo "No consumed subscription pools were found. Proceeding with migration."
      else
        exit_message "The system is registered. Please backup all the subscription-related
keys, certificates, etc. if necessary and remove the system from subscription
management service with 'subscription-manager unregister', then run this script again."
      fi
      echo "Unprotecting Red Hat-related assets..."
      rm -f /etc/yum/protected.d/{redhat-release,setup}.conf
      ;;
  esac
  if [ "$preserve" != "true" ]; then
    # Delete third-party repos' packages as well unless the 'preserve'
    # option has been specified.
    set +e
    bad_packages+=( "$(rpm -qf /etc/yum.repos.d/*.repo --qf '%{name}\n' | sort -u | grep -v '^el-release' | tr '\n' ' ')" )
    set -e
  fi
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

check_systemwide_python() {
  echo "Checking for required Python packages..."
  dep_check python2
}

find_repos_directory() {
  # Store your package manager's repositories directory for later use.
  echo "Finding your repository directory..."
      reposdir=$(python2 -c "
import yum
import os

for dir in yum.YumBase().doConfigSetup(init_plugins=False).reposdir:
  if os.path.isdir(dir):
    print dir
    break
      ")
  if [ -z "${reposdir}" ]; then
    exit_message "Could not locate your repository directory."
  fi
}

find_enabled_repos() {
  # Store your package manager's enabled repositories for later use.
  echo "Learning which repositories are enabled..."
      enabled_repos=$(python2 -c "
import yum

base = yum.YumBase()
base.doConfigSetup(init_plugins=False)
for repo in base.repos.listEnabled():
  print repo
      ")
  echo -e "Repositories enabled before update include:\n${enabled_repos}"
}

grab_gpg_keys() {
  # Get EuroLinux and CentOS 6 public GPG keys; store them in a predefined location before
  # adding any repositories.
  echo "Grabbing EuroLinux GPG keys..."
  curl "https://fbi.cdn.euro-linux.com/security/RPM-GPG-KEY-eurolinux" > "/etc/pki/rpm-gpg/RPM-GPG-KEY-eurolinux"
  curl "https://vault.centos.org/RPM-GPG-KEY-CentOS-6" > "/etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6"
}

create_temp_el_repo() {
  # Before the installation of our package that provides .repo files, we need
  # an information on where to get that and other EuroLinux packages from,
  # that are mandatory for some of the first steps before a full migration
  # (e.g.  registering to EuroMan). A temporary repository that provides these
  # packages is created here and removed later after a migration succeeds.
  # There's no need to worry about the repositories' names - even if they
  # change in future releases, the URLs will stay the same.
  # It's possible to use your own repository and provide your own .repo file
  # as a parameter - in this case no extras are created.
  cd "$reposdir"
  echo "Creating a temporary repo file for migration..."
  case "$os_version" in
    6*)
      cat > "switch-to-eurolinux.repo" <<-'EOF'
[euroman_tmp]
name=euroman_tmp
baseurl=https://elupdate.euro-linux.com/pub/enterprise-6/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-eurolinux

[fbi]
name = Free Base Image Repo
baseurl=https://fbi.cdn.euro-linux.com/dist/eurolinux/server/6/$basearch/fbi/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-eurolinux

[centos-vault-base]
name=CentOS-$releasever - Base
baseurl=https://vault.centos.org/6.10/os/x86_64/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6

[centos-vault-updates]
name=CentOS-$releasever - Updates
baseurl=https://vault.centos.org/6.10/updates/x86_64/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6

[centos-vault-extras]
name=CentOS-$releasever - Extras
baseurl=https://vault.centos.org/6.10/extras/x86_64/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6
EOF
      ;;
    *) exit_message "You appear to be running an unsupported OS version: ${os_version}." ;;
  esac
}

register_to_euroman() {
  # EuroLinux earlier than 8 requires a valid EuroMan account. The script
  # needs to know your account's credentials to register the instance it's
  # being ran on and migrate it successfully.
  # Some additional EuroLinux packages will have to be installed for that too
  # - that's the most important case of using the temporary
  # switch-to-eurolinux.repo repository. No packages from other vendors can
  # accomplish this task.
  # It's possible to use your own repository and provide your own .repo file
  # as a parameter - in this case the registration process is skipped.
  echo "Registering to EuroMan if applicable..."
  if [ -z ${el_euroman_user+x} ]; then 
    echo "Please provide your EuroMan username: "
    read el_euroman_user
  fi
  if [ -z ${el_euroman_password+x} ]; then
    echo "Please provide your EuroMan password: "
    read -s el_euroman_password
  fi
  echo "Installing EuroMan-related tools..."
  yum install -y python-hwdata rhn-client-tools rhn-check yum-rhn-plugin yum-utils rhnlib rhn-setup rhnsd
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
  # ELS Extended Life Support try this one if available if not use EL
  rhnreg_ks --force --username "$el_euroman_user" --password "$el_euroman_password" --activationkey="$el_org_id-els-$major_os_version" || \
  rhnreg_ks --force --username "$el_euroman_user" --password "$el_euroman_password" --activationkey="$el_org_id-default-$major_os_version"
}

disable_distro_repos() {

  # Remove all non-Eurolinux .repo files unless the 'preserve' option has been
  # provided. If it was, then here's a summary of the function's logic:
  # Different distros provide their repositories in different ways. There may
  # be some additional .repo files that are covered by distro X but not by
  # distro Y. The files may be provided by different packages rather than a
  # <distro>-release RPM. This function will take care of all these
  # inconsistencies to disable all the distro-specific repositories.
  # This is the case mentioned in check_supported_releases() comments about
  # overriding the old_release variable because of different .repo files'
  # provider for certain distros.
  # The procedure may be simplified but not replaced by using a '*.repo' glob 
  # since there may be some third-party repositories that should not be
  # disabled such as EPEL - only take care of another Enterprise Linux
  # repositories.

  cd "$reposdir"

  if [ "$preserve" != "true" ]; then
    set +e
    rpm -qf *.repo | grep -v 'is not owned' | sort -u | xargs rpm -e
    rm -f *.repo
    set -e
    create_temp_el_repo
  else
    cd "$(mktemp -d)"
    trap final_failure ERR

    echo "Backing up and removing old repository files..."
    > repo_files

    # ... this one should apply to any Enterprise Linux except RHEL:
    echo "Identify repo files from the base OS..."
    if [[ "$old_release" =~ redhat-release ]]; then
      echo "RHEL detected and repo files are not provided by 'release' package."
    elif [[ "$old_release" =~ el-release ]]; then
      : #do nothing
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
  fi

}

remove_centos_yum_branding() {
  # CentOS provides their branding in /etc/yum.conf. As of 2021.09.03 no other
  # distro appears to do the same but if this changes, equivalent branding
  # removals will be provided here.
  if [[ "$old_release" =~ centos ]]; then
    echo "Removing CentOS-specific yum configuration from /etc/yum.conf..."
    sed -i.bak -e 's/^distroverpkg.*//g' -e 's/^bugtracker_url.*//g' /etc/yum.conf
  fi
}

force_el_release() {
  # Get yumdownloader if applicable and force and installation of el-release,
  # removing the current release provider package.
  set +euo pipefail
  echo "Looking for yumdownloader..."
  yum -y install yum-utils
  yumdownloader el-release
  dep_check yumdownloader
  for i in "${bad_packages[@]}" ; do rpm -e --nodeps "$i" || true ; done

  rpm -i --force el-release*
  set -euo pipefail
}

remove_leftovers() {
  # Remove all temporary files and tweaks used during the migration process.
  echo "Removing yum cache..."
  rm -rf /var/cache/{yum,dnf}
  echo "Removing temporary repo..."
  rm -f "${reposdir}/switch-to-eurolinux.repo"
}

congratulations() {
  echo "Switch successful!"
}

main() {
  # All function calls.
  warning_message
  check_fips
  check_secureboot
  check_root
  check_required_packages
  check_distro
  check_supported_releases
  prepare_pre_migration_environment
  check_yum_lock
  check_systemwide_python
  find_repos_directory
  find_enabled_repos
  disable_distro_repos
  grab_gpg_keys
  create_temp_el_repo
  register_to_euroman
  remove_centos_yum_branding
  force_el_release
  remove_leftovers
  congratulations
}

while getopts "fhp:r:u:vw" option; do
    case "$option" in
        f) skip_warning="true" ;;
        h) usage ;;
        p) el_euroman_password="$OPTARG" ;;
        u) el_euroman_user="$OPTARG" ;;
        w) preserve="false" ;;
        *) usage ;;
    esac
done
main

