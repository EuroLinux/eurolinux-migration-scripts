#!/bin/bash
# Initially based on Oracle's centos2ol script. Thus licensed under the Universal Permissive License v1.0
# Copyright (c) 2020, 2021 Oracle and/or its affiliates.
# Copyright (c) 2021, 2022 EuroLinux

set -euo pipefail

# GLOBAL variables
arch="$(arch)"
answer=""
github_url="https://github.com/EuroLinux/eurolinux-migration-scripts"
logs_path="/var/tmp"
path_to_internal_repo_file=""
preserve="true"
script_dir="$(dirname $(readlink -f $0))"
skip_verification="false"
skip_warning=""
# These are all the packages we need to remove. Some may not reside in this
# array since they'll be swapped later on once EuroLinux repositories have been
# added.
bad_packages=(almalinux-backgrounds almalinux-backgrounds-extras almalinux-gpg-keys almalinux-indexhtml almalinux-logos almalinux-release almalinux-release-opennebula-addons almalinux-repos bcache-tools btrfs-progs centos-backgrounds centos-gpg-keys centos-indexhtml centos-linux-release centos-linux-repos centos-logos centos-release centos-release-advanced-virtualization centos-release-ansible26 centos-release-ansible-27 centos-release-ansible-28 centos-release-ansible-29 centos-release-azure centos-release-ceph-jewel centos-release-ceph-luminous centos-release-ceph-nautilus centos-release-ceph-octopus centos-release-configmanagement centos-release-cr centos-release-dotnet centos-release-fdio centos-release-gluster40 centos-release-gluster41 centos-release-gluster5 centos-release-gluster6 centos-release-gluster7 centos-release-gluster8 centos-release-gluster-legacy centos-release-messaging centos-release-nfs-ganesha28 centos-release-nfs-ganesha30 centos-release-nfv-common centos-release-nfv-openvswitch centos-release-openshift-origin centos-release-openstack-queens centos-release-openstack-rocky centos-release-openstack-stein centos-release-openstack-train centos-release-openstack-ussuri centos-release-opstools centos-release-ovirt42 centos-release-ovirt43 centos-release-ovirt44 centos-release-paas-common centos-release-qemu-ev centos-release-qpid-proton centos-release-rabbitmq-38 centos-release-samba411 centos-release-samba412 centos-release-scl centos-release-scl-rh centos-release-storage-common centos-release-virt-common centos-release-xen centos-release-xen-410 centos-release-xen-412 centos-release-xen-46 centos-release-xen-48 centos-release-xen-common centos-repos desktop-backgrounds-basic insights-client kernel-uek kernel-uek-core kernel-uek-modules libreport-centos libreport-plugin-mantisbt libreport-plugin-rhtsupport libreport-rhel libreport-rhel-anaconda-bugzilla libreport-rhel-bugzilla libdtrace-ctf linux-firmware-core oracle-backgrounds oracle-epel-release-el8 oracle-indexhtml oraclelinux-release oraclelinux-release-el7 oraclelinux-release-el8 oraclelinux-release-el9 oracle-logos python3-dnf-plugin-ulninfo python3-syspurpose python-oauth redhat-backgrounds Red_Hat_Enterprise_Linux-Release_Notes-7-en-US redhat-indexhtml redhat-logos redhat-release redhat-release-eula redhat-release-server redhat-support-lib-python redhat-support-tool rhc thnlib rocky-backgrounds rocky-gpg-keys rocky-indexhtml rocky-logos rocky-obsolete-packages rocky-release rocky-repos sl-logos uname26 yum-conf-extras yum-conf-repos)


usage() {
    echo "Usage: ${0##*/} [OPTIONS]"
    echo
    echo "OPTIONS"
    echo "-f      Skip warning messages"
    echo "-h      Display this help and exit"
    echo "-l      Override default logs path (/var/tmp)"
    echo "-r      Use a custom .repo file (for offline migration)"
    echo "-v      Don't verify RPMs"
    echo "-w      Remove all detectable non-EuroLinux extras"
    echo "        (e.g. third-party repositories and backed-up .repo files)"
    echo
    echo "OPTIONS applicable to Enterprise Linux 7 or older"
    echo "-u      Your EuroMan username (usually an email address)"
    echo "-p      Your EuroMan password"
    exit 1
}

warning_message() {
  # Display a warning message about backups unless running non-interactively
  # (assumed default behavior).
  if [ "$skip_warning" != "true" ]; then
    echo "This script will migrate your existing Enterprise Linux system to EuroLinux. Extra precautions have been arranged but there's always the risk of something going wrong in the process and users are always recommended to make a backup."
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
    exit_message "You appear to be running a system in FIPS mode, which is not supported for migration. This case requires an individual migration approach that can be received by contacting our technical department. Please use the medium our sales department provided after a subscription has been purchased."
  fi
}

check_secureboot(){
  if grep -oq 'Secure Boot: enabled' <(bootctl 2>&1) ; then
    exit_message "You appear to be running a system with Secure Boot enabled, which is not yet supported for migration. Disable it first, then run the script again."
  fi
}

generate_rpms_info() {
  # Generate an RPM database log and a list of RPMs installed on your system
  # at any point in time.
  set +euo pipefail
  if [ "$skip_verification" != "true" ]; then
    # $1 - before/after (a migration)
    echo "Creating a list of RPMs installed $1 the switch..."
    rpm -qa --qf "%{NAME}-%{EPOCH}:%{VERSION}-%{RELEASE}.%{ARCH}|%{INSTALLTIME}|%{VENDOR}|%{BUILDTIME}|%{BUILDHOST}|%{SOURCERPM}|%{LICENSE}|%{PACKAGER}\n" | sed 's/(none)://g' | sort > "${logs_path}/$(hostname)-rpms-list-$1.log"
    echo "Verifying RPMs installed $1 the switch against RPM database... - ${logs_path}/$(hostname)-rpms-list-$1.log"
    rpm -Va | sort -k3 > "${logs_path}/$(hostname)-rpms-verified-$1.log"
  fi
  set -euo pipefail
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

verify_rpms_before_migration() {
  generate_rpms_info before
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
  # Determine the exact details a distro exposes to perform a migration
  # successfully - some distros and their releases will need different
  # approaches and tweaks. Store these details for later use.
  os_version=$(rpm -q "${old_release}" --qf "%{version}")
  major_os_version=${os_version:0:1}
  base_packages=(basesystem grub2 grubby initscripts plymouth)
  
  set +e
  for file in /etc/yum/protected.d/*.conf ; do mv "${file}" "${file}.disabled" ; done
  set -e
  
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

backup_internal_repo_file() {
  if [ -n "$path_to_internal_repo_file" ]; then
    cp "$path_to_internal_repo_file" "/root/${path_to_internal_repo_file##*/}"
    path_to_internal_repo_file="/root/${path_to_internal_repo_file##*/}"
  fi
}

check_systemwide_python() {
  # This script has an embedded Python code for several operations that are
  # expressed better that way rather than via a shell. It will need a Python
  # interpreter. This check ensures the proper locations and version of the
  # interpreter (the exact invocations will be used later in the script).
  # Once the embedded Python code is present, it's written for that exact
  # system-wide interpreter and integrated with other system-wide components -
  # no incompatibilities as long as the system has the tools installed from
  # its official repositories and no unofficial tweaks have been made (e.g.
  # replacing a system-wide Python 2 with 3).
  echo "Checking for required Python packages..."
  case "$os_version" in
    8*|9*)
      dep_check /usr/libexec/platform-python
      ;;
    *)
      dep_check python2
      ;;
  esac
}

find_repos_directory() {
  # Store your package manager's repositories directory for later use.
  echo "Finding your repository directory..."
  case "$os_version" in
    8*|9*)
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
  # Store your package manager's enabled repositories for later use.
  echo "Learning which repositories are enabled..."
  case "$os_version" in
    8*|9*)
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
  # Get EuroLinux public GPG keys; store them in a predefined location before
  # adding any repositories.
  if [ -z "$path_to_internal_repo_file" ]; then
    echo "Grabbing EuroLinux GPG keys..."
    curl "https://fbi.cdn.euro-linux.com/security/RPM-GPG-KEY-eurolinux$major_os_version" > "/etc/pki/rpm-gpg/RPM-GPG-KEY-eurolinux$major_os_version"
  fi
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
  if [ -n "$path_to_internal_repo_file" ]; then
    cp "$path_to_internal_repo_file" "$reposdir/switch-to-eurolinux.repo"
  else
    cd "$reposdir"
    echo "Creating a temporary repo file for migration..."
    case "$os_version" in
      8*|9*)
        cat > "switch-to-eurolinux.repo" <<-EOF
[certify-baseos]
name = EuroLinux certify BaseOS
baseurl=https://fbi.cdn.euro-linux.com/dist/eurolinux/server/${major_os_version}/\$basearch/BaseOS/os
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-eurolinux${major_os_version}
skip_if_unavailable=1

[certify-appstream]
name = EuroLinux certify AppStream
baseurl=https://fbi.cdn.euro-linux.com/dist/eurolinux/server/${major_os_version}/\$basearch/AppStream/os
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-eurolinux${major_os_version}
skip_if_unavailable=1

[certify-powertools]
name = EuroLinux certify PowerTools/CRB
baseurl=https://fbi.cdn.euro-linux.com/dist/eurolinux/server/${major_os_version}/\$basearch/PowerTools/os
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-eurolinux${major_os_version}
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
  fi
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
  if [ -z "$path_to_internal_repo_file" ]; then
    echo "Registering to EuroMan if applicable..."
    case "$os_version" in
      8*|9*)
        echo "EuroLinux ${major_os_version} is Open Core, not registering."
        ;;
      *)
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
        rhnreg_ks --force --username "$el_euroman_user" --password "$el_euroman_password" --activationkey="$el_org_id-default-$major_os_version"
        ;;
    esac
  fi
}

check_el_repos_connectivity() {
  # Perform a `yum makecache` to check if we can successfully connect to
  # EuroLinux repositories. Just an additional check for safety in case there's
  # something going on with the connection so we know in advance to fix it now
  # rather than later.
  # The commands mentioned appear to return 0 anyway on Enterprise Linux 8 so
  # we need an additional logic for checking for 404s rather than relying on
  # status codes. The same logic has been applied for Enterprise Linux 7 for
  # consistency.
  if [ ! -n "$path_to_internal_repo_file" ]; then
    echo "Checking EuroLinux repositories connectivity..."
      set +euo pipefail
      case "$os_version" in
        8*|9*)
          yum --verbose --refresh --disablerepo="*" --enablerepo=certify-{baseos,appstream,powertools} makecache \
            |& grep --color=auto 'error: Status code: 404' && final_failure
          ;;
        7*)
          echo "(The connectivity check may take a long time on Enterprise Linux 7.)"
          yum --verbose --refresh --disablerepo="*" --enablerepo={fbi,el-server-7-x86_64} makecache \
            |& grep --color=auto 'HTTPS Error 404 - Not Found' && final_failure
          ;;
      esac
      set -euo pipefail
  fi
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

    # Most distros keep their /etc/yum.repos.d content in the -release rpm. Some do not and here are the tweaks for their more complex solutions...
    case "$old_release" in
      centos-release-8.*|centos-linux-release-8.*)
        old_release=$(rpm -qa centos*repos) ;;
      rocky-release*)
        old_release=$(rpm -qa rocky*repos) ;;
      oraclelinux-release-9.*)
        old_release=$(rpm -qa oraclelinux-release-el9*) ;;
      oraclelinux-release-8.*)
        old_release=$(rpm -qa oraclelinux-release-el8*) ;;
      oraclelinux-release-7.*)
        old_release=$(rpm -qa oraclelinux-release-el7*) ;;
      *) : ;;
    esac

    echo "Backing up and removing old repository files..."
    > repo_files

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

fix_oracle_shenanigans() {
  # Several packages in Oracle Linux have a different naming convention. These
  # are incompatible with other Enterprise Linuxes and treated as newer
  # versions by package managers. For a migration we need to 'downgrade' them
  # to EuroLinux equivalents once EuroLinux repositories have been added.
  #
  # Some Oracle Linux exclusive packages with no equivalents will be removed
  # as well. Oracle-branded enabled modules will be reset here and their names
  # stored for later use once a distro-sync has been performed.
  set +euo pipefail
  if [[ "$old_release" =~ oracle ]]; then
    echo "Dealing with Oracle Linux curiosities..."
    rpm -e --nodeps $(rpm -qa | grep "oracle")
    yum downgrade --skip-broken -y yum 
    yum downgrade --skip-broken -y $(for suffixable in $(rpm -qa | egrep "\.0\.[1-9]\.el") ; do rpm -q $suffixable --qf '%{NAME}\n' ; done)
    unlink /etc/os-release || true
    case "$os_version" in
      9*)
        yum remove -y --skip-broken python3-hwdata rhnlib python3-rhnlib python3-rhn-client-tools rhn-client-tools 
        ;;
      8*)
        yum remove --skip-broken -y bcache-tools btrfs-progs python3-dnf-plugin-ulninfo
        echo "Getting the list of Oracle-branded modules..."
        oracle_modules_enabled=( $(dnf module list --enabled | grep ' ol8' | cut -d ' ' -f 1) )
        oracle_modules_installed=( $(dnf module list --installed | grep ' ol8' | cut -d ' ' -f 1) )
        [ -n "${oracle_modules_enabled[*]}" ] && dnf module reset -y ${oracle_modules_enabled[*]} || echo "(No Oracle-branded modules found)"
        ;;
      7*)
        yum remove -y --skip-broken uname26 libdtrace-ctf
        ;;
    esac
    set -euo pipefail
  fi
}

force_el_release() {
  # Get yumdownloader if applicable and force and installation of el-release,
  # removing the current release provider package.
  set +euo pipefail
  case "$os_version" in
      8*|9*)
        : # 'yum-utils' already provided my dnf, skipping
        dnf download el-release
        ;;
      7*)
        echo "Looking for yumdownloader..."
        yum -y install yum-utils
        yumdownloader el-release
        dep_check yumdownloader
        ;;
  esac
  for i in "${bad_packages[@]}" ; do rpm -e --nodeps "$i" || true ; done

  # Additional tweak for RHEL 8 - remove these directories manually.
  # Otherwise an error will show up:
  # error: unpacking of archive failed on file [...]: cpio: File from 
  # package already exists as a directory in system
  if [[ "$old_release" =~ redhat-release ]]; then
    echo "RHEL detected - removing 'redhat-release*' directories manually."
    rm -rf /usr/share/doc/redhat-release* /usr/share/redhat-release*
  fi

  rpm -i --force el-release*
  echo "el-release" > /etc/yum/protected.d/el-release.conf
  set -euo pipefail
}

disable_el_repos_if_custom_repo_is_provided() {
  # If a custom repo file is provided, do not use the repos we install with
  # el-release. This also applies if one wants to use our Vault and migrate
  # from an Enterprise Linux 8.4 (old version) to EuroLinux 8.4.
  if [ -n "$path_to_internal_repo_file" ]; then
    case "$os_version" in
      8.6|8.7|8.8|8.9|8.10|9*)
        # Disabling the repos for offline migration is applicable to EL8 only
        # since on EL7 the core repos are skipped along with skipping EuroMan
        # registration. These below are provided by the el-release package.
        echo "Disabling the EuroLinux 8-provided repos for offline migration..."
        dnf config-manager --disable {baseos,appstream,powertools}
        ;;
      8.3|8.4|8.5)
        echo "Disabling the EuroLinux 8-provided 'certify' repos for offline migration..."
        dnf config-manager --disable certify-{baseos,appstream,powertools}
        ;;
      7*)
        echo "EuroLinux 7 core repos have been already skipped along with skipping EuroMan registration by using a custom .repo"
        ;;
    esac
  fi
}

install_el_base() {
  # Remove packages from other Enterprise Linux distros and install ours. It's
  # vital that this be performed in one go such as with `yum shell` so the
  # important dependencies are replaced with ours rather than failing to be
  # removed by a package manager.
  echo "Installing base packages for EuroLinux..."

  case "$os_version" in
    8*|9*)
      if ! yum shell -y <<EOF
      remove ${bad_packages[@]}
      install ${base_packages[@]}
      run
EOF
      then
        exit_message "Could not install base packages. Run 'yum distro-sync' to manually install them."
      fi
      ;;
    7*)
      yum reinstall -y \*
      ;;
  esac
}

update_initrd() {
  # Create a new initrd with EuroLinux bootsplash
  if [ -x /usr/libexec/plymouth/plymouth-update-initrd ]; then
    echo "Updating initrd..."
    /usr/libexec/plymouth/plymouth-update-initrd
  fi
}

el_distro_sync() {
  # Make sure all packages are synchronized with the ones EuroLinux provides.
  echo "Switch successful. Syncing with EuroLinux repositories..."
  if ! yum -y distro-sync ; then
    exit_message "Could not automatically sync with EuroLinux repositories.
  Check the output of 'yum distro-sync' to manually resolve the issue."
  fi
}

restore_modules() {
  # Restore the modules that were previously Oracle-branded.
  # First, check if the system the migration is taking place on was Oracle
  # Linux - otherwise it's pointless to run all these checks.
  if [[ "$old_release" =~ oracle ]]; then
    echo "Restoring modules that were Oracle-branded if applicable..."
    case "$os_version" in
      8*)
        if [ -n "${oracle_modules_enabled[*]}" ]; then
            eurolinux_modules_to_enable=( $(echo ${oracle_modules_enabled[*]} | sed -E 's@ @:rhel8 @g;s@$@:rhel8@g') )
            echo "Reenabling the modules: ${eurolinux_modules_to_enable[*]}..."
            dnf module enable -y ${eurolinux_modules_to_enable[*]}
        fi
        if [ -n "${oracle_modules_installed[*]}" ]; then
            eurolinux_modules_to_install=( $(echo ${oracle_modules_installed[*]} | sed -E 's@ @:rhel8 @g;s@$@:rhel8@g') )
            echo "Reinstalling the modules: ${eurolinux_modules_to_install[*]}..."
            dnf module install -y ${eurolinux_modules_to_install[*]}
        fi
        echo "Module restoration done."
      ;;
      *) echo "(Non-applicable)" ;;
    esac
  fi
}

deal_with_problematic_rpms() {
  # Some RPMs are either not covered by 'replaces' metadata or couldn't be
  # replaced earlier. This part takes care of all of them.
  # In some cases these can be replaced automatically but until additional
  # tests have been performed, this logic is kept here.
  if [[ "$(rpm -qa '*-logos-ipa' | grep -v 'el-logos-ipa')" ]]; then
    yum swap -y "*-logos-ipa" "el-logos-ipa"
  fi

  if [[ "$(rpm -qa '*-logos-httpd' | grep -v 'el-logos-httpd')" ]]; then
    yum swap -y "*-logos-httpd" "el-logos-httpd"
  fi

  # libzstd - required during the migration process, can be removed now
  yum remove -y libzstd || true

  # A necessary downgrade to the version from our repos since the 'virt'
  # module gets installed when debranding Oracle Linux modules. It may fail
  # and a removal is performed as a fallback action.
  case "$os_version" in
    8*)
      [ $(rpm -qa "qemu-guest-agent") ] && sudo dnf downgrade -y qemu-guest-agent || sudo dnf remove -y qemu-guest-agent ;;
    *) : ;;
  esac
}

fix_reinstalled_rpms() {
  # Reinstalling OpenJDK packages breaks their links in /etc/alternatives:
  # https://bugzilla.redhat.com/show_bug.cgi?id=1976053
  rpm -qa --scripts java-*-openjdk-* | sed -n '/postinstall/, /exit/{ /postinstall/! { /exit/ ! p} }' | sh

  # After reinstalling IPA we need to perform an 'upgrade' to make it work again.
  set +euo pipefail
  [ "$(rpm -qa 'ipa-server' | grep module)" ] && ipa-server-upgrade --skip-version-check
  set -euo pipefail
}

compare_all_rpms() {
  set +u
  declare internal_repo_pattern=""
  declare -a non_eurolinux_rpms_from_yum_list
  declare -a non_eurolinux_rpms_and_metadata
  declare -a non_eurolinux_rpms_and_metadata_without_kernel_related

  # Once an internal .repo file is provided, search for the names of the
  # offline repositories and construct them as a grep pattern. Take a look
  # at the pipe symbol: | before a command substitution takes place - it
  # will be used for appending the result to `grep -Ev [...]` and will work
  # even if the variable is nonexistent.
  if [ -n "$path_to_internal_repo_file" ]; then
    internal_repo_pattern="|$(grep -oP '\[\K[^\]]+' "$path_to_internal_repo_file" | xargs echo | sed 's/ /|/g')"
  fi

  # Query all packages and their metadata such as their Vendor. The result of
  # the query will be stored in a Bash array named non_eurolinux_rpms[...].
  # Since earlier EuroLinux packages are branded as Scientific Linux, an
  # additional pattern is considered when looking up EuroLinux products.
  # Some packages may not be branded properly - we use `yum` to determine
  # their origin and then check with `rpm`.
  # When listing packages with `yum`, there may be a few which are listed with
  # two lines rather than one due to their long filename - the output is
  # modified via `sed` to deal with this curiosity.
  # To complicate things even further, two packages (rhnlib and rhnsd)
  # are not branded. They are excluded from the non-EuroLinux RPM list.
  mapfile -t non_eurolinux_rpms_from_yum_list < <(yum list installed | sed '/^[^@]*$/{N;s/\n//}' | grep -Ev '@el-server-|@euroman|@fbi|@certify'"$internal_repo_pattern" | grep '@' | cut -d' ' -f 1 | cut -d'.' -f 1)
  mapfile -t non_eurolinux_rpms_and_metadata < <(rpm -qa --qf "%{NEVRA}|%{VENDOR}|%{PACKAGER}\n" ${non_eurolinux_rpms_from_yum_list[*]} | grep -Ev 'EuroLinux|Scientific' | sed 's@\ @\_@g' | grep -Ev '^(rhnlib|rhnsd).+\|\(none\)\|\(none\)$') 
  if [[ -n "${non_eurolinux_rpms_and_metadata[*]}" ]]; then
    echo "The following non-EuroLinux RPMs are installed on the system:"
    printf '\t%s\n' "${non_eurolinux_rpms_and_metadata[@]}"
    echo "This may be expected of your environment and does not necessarily indicate a problem."
    echo "If a large number of RPMs from other vendors are included and you're unsure why please open an issue on ${github_url}"
    if [ "$preserve" != "true" ]; then
      echo "Removing these packages (except those kernel-related) automatically..."
      non_eurolinux_rpms_and_metadata_without_kernel_related=( ${non_eurolinux_rpms_and_metadata[@]/kernel*/} )
      if [ ${#non_eurolinux_rpms_and_metadata_without_kernel_related[@]} -gt 0 ]; then
        yum remove -y ${non_eurolinux_rpms_and_metadata_without_kernel_related[@]%%|*}
      else
        echo "(no need to remove anything)"
      fi
    fi
  fi
  set -u
}

remove_distro_gpg_pubkey() {
  keys="$(rpm -qa --qf '%{nevra} %{packager}\n' gpg-pubkey*)"
  if [ "$preserve" == "true" ]; then
    # We need to make sure only the pubkeys of the vendors that provide the
    # distros we're migrating from are removed and only these. As of today the
    # solution is to have an array with their emails and make sure the
    # corresponding pubkeys are removed.
    bad_providers=('packager@almalinux.org' 'security@centos.org' 'build@oss.oracle.com' 'security@redhat.com' 'infrastructure@rockylinux.org' 'scientific-linux-devel@fnal.gov' )
    for provider in ${bad_providers[*]} ; do
      echo "Checking for the existence of gpg-pubkey provider: $provider..."
      grep -i $provider <<< "$keys" | cut -d' ' -f 1 | xargs rpm -e || true
    done
  else
    # On the other hand if we want to remove everything not related to
    # EuroLinux, remove all of these keys unless they end with
    # '@euro-linux.com'
    echo "Checking for the existence of non-EuroLinux gpg-pubkeys and removing them..."
    grep -v '@euro-linux.com' <<< "$keys" | cut -d' ' -f 1 | xargs rpm -e || true
  fi
}

update_bootloader() {
  # Update bootloader entries and EFI boot if appropriate.
  if [ -d /sys/firmware/efi ]; then
    echo "Performing preliminary tasks for updating EFI boot..."
    if [ "$arch" == "x86_64"]; then
      yum install -y efibootmgr grub2-efi-x64 mokutil shim-x64
    elif [ "$arch" == "aarch64" ]; then
      yum install -y efibootmgr grub2-efi-aa64 mokutil shim-aa64
    fi
    grub2_conf="/etc/grub2-efi.cfg"
    efi_device="$(findmnt --noheadings --target /boot/efi --output source)"
    efi_kname="$(lsblk -dno kname $efi_device)"
    efi_pkname="$(lsblk -dno pkname $efi_device)"
    efi_partition="$(cat /sys/block/$efi_pkname/$efi_kname/partition)" # Should be "1" by default but let's check just in case...
  else
    grub2_conf="/etc/grub2.cfg"
  fi
  echo "Updating the GRUB2 bootloader at $grub2_conf (symlinked to $(readlink $grub2_conf))."
  grub2-mkconfig -o "$grub2_conf"
  if [ -d /sys/firmware/efi ]; then
    echo "Updating EFI boot."
    if [ "$arch" == "x86_64"]; then
      efibootmgr -c -d "/dev/$efi_pkname" -l "/EFI/eurolinux/shimx64.efi" -L "EuroLinux $major_os_version" -p "$efi_partition" -v
    elif [ "$arch" == "aarch64" ]; then
      efibootmgr -c -d "/dev/$efi_pkname" -l "/EFI/eurolinux/shimaa64.efi" -L "EuroLinux $major_os_version" -p "$efi_partition" -v
    fi
  fi
}

remove_leftovers() {
  # Remove all temporary files and tweaks used during the migration process.
  echo "Removing yum cache..."
  rm -rf /var/cache/{yum,dnf}
  echo "Removing temporary repo..."
  if [ -z "$path_to_internal_repo_file" ]; then
    rm -f "${reposdir}/switch-to-eurolinux.repo"
  else
    echo "Since a custom repo has been provided, it will be used from now on as ${reposdir}/eurolinux-offline.repo"
    echo "Reminder: the repos provided by the el-release package are kept as disabled."
    mv "${reposdir}/switch-to-eurolinux.repo" "${reposdir}/eurolinux-offline.repo"
  fi
}

verify_generated_rpms_info() {
  generate_rpms_info after
  if [ "$skip_verification" != "true" ]; then
    echo "Review the output of following files:"
    find "${logs_path}" -type f -name "$(hostname)-rpms-*.log"
  fi
}

remove_kernels_and_related_packages() {
  # The answer on what to remove
  # See the remove_kernels.sh's usage() for more information.
  [ "$preserve" == "true" ] && removal_answer=3 || removal_answer=2
  echo "Running ./remove_kernels.sh -a $removal_answer..."
  cd "$script_dir"
  ./remove_kernels.sh -a $removal_answer
}

congratulations() {
  echo "Switch almost complete. EuroLinux recommends rebooting this system.
Once booted up, a background service will perform a further kernel removal."
}

main() {
  # All function calls.
  warning_message
  check_fips
  check_secureboot
  check_root
  check_required_packages
  check_distro
  verify_rpms_before_migration
  check_supported_releases
  prepare_pre_migration_environment
  check_yum_lock
  backup_internal_repo_file
  check_systemwide_python
  find_repos_directory
  find_enabled_repos
  grab_gpg_keys
  create_temp_el_repo
  register_to_euroman
  check_el_repos_connectivity
  disable_distro_repos
  fix_oracle_shenanigans
  remove_centos_yum_branding
  force_el_release
  disable_el_repos_if_custom_repo_is_provided
  install_el_base
  update_initrd
  el_distro_sync
  restore_modules
  deal_with_problematic_rpms
  fix_reinstalled_rpms
  compare_all_rpms
  remove_distro_gpg_pubkey
  update_bootloader
  remove_leftovers
  verify_generated_rpms_info
  remove_kernels_and_related_packages
  congratulations
}

while getopts "fhl:p:r:u:vw" option; do
    case "$option" in
        f) skip_warning="true" ;;
        h) usage ;;
        l) logs_path="$OPTARG" ;;
        p) el_euroman_password="$OPTARG" ;;
        r) path_to_internal_repo_file="$OPTARG" ;;
        u) el_euroman_user="$OPTARG" ;;
        v) skip_verification="true" ;;
        w) preserve="false" ;;
        *) usage ;;
    esac
done
main

