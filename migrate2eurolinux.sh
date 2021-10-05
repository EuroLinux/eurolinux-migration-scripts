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
  bad_packages=(almalinux-backgrounds almalinux-backgrounds-extras almalinux-indexhtml almalinux-logos almalinux-release almalinux-release-opennebula-addons bcache-tools btrfs-progs centos-backgrounds centos-gpg-keys centos-indexhtml centos-linux-release centos-linux-repos centos-logos centos-release centos-release-advanced-virtualization centos-release-ansible26 centos-release-ansible-27 centos-release-ansible-28 centos-release-ansible-29 centos-release-azure centos-release-ceph-jewel centos-release-ceph-luminous centos-release-ceph-nautilus centos-release-ceph-octopus centos-release-configmanagement centos-release-cr centos-release-dotnet centos-release-fdio centos-release-gluster40 centos-release-gluster41 centos-release-gluster5 centos-release-gluster6 centos-release-gluster7 centos-release-gluster8 centos-release-gluster-legacy centos-release-messaging centos-release-nfs-ganesha28 centos-release-nfs-ganesha30 centos-release-nfv-common centos-release-nfv-openvswitch centos-release-openshift-origin centos-release-openstack-queens centos-release-openstack-rocky centos-release-openstack-stein centos-release-openstack-train centos-release-openstack-ussuri centos-release-opstools centos-release-ovirt42 centos-release-ovirt43 centos-release-ovirt44 centos-release-paas-common centos-release-qemu-ev centos-release-qpid-proton centos-release-rabbitmq-38 centos-release-samba411 centos-release-samba412 centos-release-scl centos-release-scl-rh centos-release-storage-common centos-release-virt-common centos-release-xen centos-release-xen-410 centos-release-xen-412 centos-release-xen-46 centos-release-xen-48 centos-release-xen-common desktop-backgrounds-basic insights-client libreport-centos libreport-plugin-mantisbt libreport-plugin-rhtsupport libreport-rhel libreport-rhel-anaconda-bugzilla libreport-rhel-bugzilla oracle-backgrounds oracle-epel-release-el8 oracle-indexhtml oraclelinux-release oraclelinux-release-el7 oraclelinux-release-el8 oracle-logos python3-dnf-plugin-ulninfo python3-syspurpose python-oauth redhat-backgrounds Red_Hat_Enterprise_Linux-Release_Notes-7-en-US redhat-indexhtml redhat-logos redhat-release redhat-release-eula redhat-release-server redhat-support-lib-python redhat-support-tool rocky-backgrounds rocky-gpg-keys rocky-indexhtml rocky-logos rocky-obsolete-packages rocky-release rocky-repos sl-logos uname26 yum-conf-extras yum-conf-repos)
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

generate_rpms_info() {
  # Generate an RPM database log and a list of RPMs installed on your system
  # at any point in time.
  # $1 - before/after (a migration)
  echo "Creating a list of RPMs installed $1 the switch..."
  rpm -qa --qf "%{NAME}-%{EPOCH}:%{VERSION}-%{RELEASE}.%{ARCH}|%{INSTALLTIME}|%{VENDOR}|%{BUILDTIME}|%{BUILDHOST}|%{SOURCERPM}|%{LICENSE}|%{PACKAGER}\n" | sed 's/(none)://g' | sort > "/var/tmp/$(hostname)-rpms-list-$1.log"
  echo "Verifying RPMs installed $1 the switch against RPM database..."
  rpm -Va | sort -k3 > "/var/tmp/$(hostname)-rpms-verified-$1.log"
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
  echo "Collecting information about RPMs before the switch..."
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
  base_packages=(basesystem el-logos el-release grub2 grubby initscripts plymouth)
  if [[ "$old_release" =~ oraclelinux-release-(el)?[78] ]] ; then
    echo "Oracle Linux detected - unprotecting systemd temporarily for distro-sync to succeed..."
    mv /etc/yum/protected.d/systemd.conf /etc/yum/protected.d/systemd.conf.bak
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
    8*)
      dep_check /usr/libexec/platform-python
      ;;
    *)
      dep_check python2
      ;;
  esac
}

get_branded_modules() {
  # Oracle Linux 8 modules are branded with 'ol8'. If one happens to be
  # enabled, add it to an array for later use. There can also be some modules
  # present that the script can't manage - if that happens, ask on what to do
  # next.
  if [[ "$os_version" =~ 8.* ]]; then
    echo "Identifying dnf modules that are enabled..."
    mapfile -t modules_enabled < <(dnf module list --enabled | grep -E 'ol8?\ \[' | awk '{print $1}')
    if [[ "${modules_enabled[*]}" ]]; then
      # Create an array of modules we don't know how to manage
      unknown_modules=()
      for module in "${modules_enabled[@]}"; do
        case ${module} in
          container-tools|go-toolset|jmc|llvm-toolset|rust-toolset|virt)
            ;;
          *)
            # Add this module name to our array of modules we don't know how
            # to manage
            unknown_modules+=("${module}")
            ;;
        esac
      done
      # If we have any modules we don't know how to manage, ask the user how
      # to proceed
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
  # Store your package manager's repositories directory for later use.
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
  # Store your package manager's enabled repositories for later use.
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
  # Get EuroLinux public GPG keys; store them in a predefined location before
  # adding any repositories.
  echo "Grabbing EuroLinux GPG keys..."
  curl "https://fbi.cdn.euro-linux.com/security/RPM-GPG-KEY-eurolinux$major_os_version" > "/etc/pki/rpm-gpg/RPM-GPG-KEY-eurolinux$major_os_version"
}

create_temp_el_repo() {
  # Before the installation of our package that provides .repo files, we need
  # an information on where to get that and other EuroLinux packages from,
  # that are mandatory for some of the first steps before a full migration
  # (e.g.  registering to EuroMan). A temporary repository that provides these
  # packages is created here and removed later after a migration succeeds.
  # There's no need to worry about the repositories' names - even if they
  # change in future releases, the URLs will stay the same.
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
  # EuroLinux earlier than 8 requires a valid EuroMan account. The script
  # needs to know your account's credentials to register the instance it's
  # being ran on and migrate it successfully.
  # Some additional EuroLinux packages will have to be installed for that too
  # - that's the most important case of using the temporary
  # switch-to-eurolinux.repo repository. No packages from other vendors can
  # accomplish this task.
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
}

remove_distro_gpg_pubkey() {
  # We need to make sure only the pubkeys of the vendors that provide the
  # distros we're migrating from are removed and only these. As of today the
  # solution is to have an array with their emails and make sure the
  # corresponding pubkeys are removed.
  bad_providers=('packager@almalinux.org' 'security@centos.org' 'build@oss.oracle.com' 'security@redhat.com' 'infrastructure@rockylinux.org' 'scientific-linux-devel@fnal.gov')
  keys="$(rpm -qa --qf '%{nevra} %{packager}\n' gpg-pubkey*)"
  for provider in ${bad_providers[*]} ; do
    grep -i $provider <<< "$keys" | cut -d' ' -f 1 | xargs rpm -e
  done
}

disable_distro_repos() {
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
  # CentOS provides their branding in /etc/yum.conf. As of 2021.09.03 no other
  # distro appears to do the same but if this changes, equivalent branding
  # removals will be provided here.
  if [[ "$old_release" =~ centos ]]; then
    echo "Removing CentOS-specific yum configuration from /etc/yum.conf..."
    sed -i.bak -e 's/^distroverpkg/#&/g' -e 's/^bugtracker_url/#&/g' /etc/yum.conf
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
  if [[ "$(rpm -qa 'oraclelinux-release-el*')" ]]; then
    rpm -e --nodeps $(rpm -qa | grep "oracle")
    yum downgrade -y yum
    yum downgrade -y $(for suffixable in $(rpm -qa | egrep "\.0\.[1-9]\.el") ; do rpm -q $suffixable --qf '%{NAME}\n' ; done)
    unlink /etc/os-release || true
    case "$os_version" in
      8*)
        yum remove -y bcache-tools btrfs-progs python3-dnf-plugin-ulninfo 
        ;;
      7*)
        yum remove -y uname26
        ;;
      esac
  fi
}

force_el_release() {
  # Get yumdownloader if applicable and force and installation of el-release,
  # removing the current release provider package.
  if ! command -v yumdownloader; then
    case "$os_version" in
        8*)
          : # Already provided my dnf, skipping
          dnf download el-release
          ;;
        7*)
          echo "Looking for yymdownloader..."
          yum -y install yum-utils
          yum download el-release
          dep_check yumdownloader
          ;;
    esac
    for i in ${bad_packages[@]} ; do rpm -e --nodeps $i || true ; done

    # Additional tweak for RHEL 8 - remove these directories manually.
    # Otherwise an error will show up:
    # error: unpacking of archive failed on file [...]: cpio: File from 
    # package already exists as a directory in system
    if [[ "$old_release" =~ redhat-release-8 ]]; then
      echo "RHEL 8 detected - removing 'redhat-release*' directories manually."
      rm -rf /usr/share/doc/redhat-release* /usr/share/redhat-release*
    fi

    rpm -i --force el-release*
fi
}

install_el_base() {
  # Remove packages from other Enterprise Linux distros and install ours. It's
  # vital that this be performed in one go such as with `yum shell` so the
  # important dependencies are replaced with ours rather than failing to be
  # removed by a package manager.
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
  # Create a new initrd with EuroLinux bootsplash
  if [ -x /usr/libexec/plymouth/plymouth-update-initrd ]; then
    echo "Updating initrd..."
    /usr/libexec/plymouth/plymouth-update-initrd
  fi
}

el_distro_sync() {
  # Make sure all packages are synchronized with the ones EuroLinux provides.
  echo "Switch successful. Syncing with EuroLinux repositories..."
  if ! yum -y distro-sync; then
    exit_message "Could not automatically sync with EuroLinux repositories.
  Check the output of 'yum distro-sync' to manually resolve the issue."
  fi
}

debrand_modules() {
  # Use the previously acquired array of known modules to switch them to
  # EuroLinux-branded ones.
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
        # EuroLinux 8 repositories are named with 'certify-' prefix for a
        # purpose - this is the case of a simple matching that works with this
        # naming convention.
        dnf --assumeyes --disablerepo "*" --enablerepo "certify*" update
      fi
      ;;
    *) : ;;
  esac
}

deal_with_problematic_rpms() {
  # Some RPMs are either not covered by 'replaces' metadata or couldn't be
  # replaced earlier. This part takes care of all of them.
  if [[ "$(rpm -qa '*-logos-ipa')" ]]; then
    yum swap -y "*-logos-ipa" "el-logos-ipa"
  fi

  if [[ "$(rpm -qa '*-logos-httpd')" ]]; then
    yum swap -y "*-logos-httpd" "el-logos-httpd"
  fi

  # libzstd - required during the migration process, can be removed now
  yum remove -y libzstd || true

  # A necessary downgrade to the version from our repos since the 'virt'
  # module gets installed when debranding Oracle Linux modules
  case "$os_version" in
    8*)
      dnf downgrade -y qemu-guest-agent || true
      ;;
    *) : ;;
  esac
}

reinstall_all_rpms() {
  # A safety measure - all packages will be reinstalled and then compared if
  # they belong to EuroLinux or not. If not, this might not be a problem at
  # all - it depends if they are from other vendors you migrated from or third
  # party repositories such as EPEL.
  echo "Reinstalling all RPMs..."
  yum reinstall -y \*

  # Query all packages and their metadata such as their Vendor. The result of
  # the query will be stored in a Bash array named non_eurolinux_rpms.
  # Since earlier EuroLinux packages are branded as Scientific Linux, an
  # additional pattern is considered when looking up EuroLinux products.
   mapfile -t non_eurolinux_rpms < <(rpm -qa --qf "%{NAME}-%{VERSION}-%{RELEASE}|%{VENDOR}|%{PACKAGER}\n" |grep -Ev 'EuroLinux|Scientific') 
  if [[ -n "${non_eurolinux_rpms[*]}" ]]; then
    echo "The following non-EuroLinux RPMs are installed on the system:"
    printf '\t%s\n' "${non_eurolinux_rpms[@]}"
    echo "This may be expected of your environment and does not necessarily indicate a problem."
    echo "If a large number of RPMs from other vendors are included and you're unsure why please open an issue on ${github_url}"
  fi
}

update_grub() {
  # Update bootloader entries. Output to a symlink which always points to the
  # proper configuration file.
  printf "Updating the GRUB2 bootloader at: "
  [ -d /sys/firmware/efi ] && grub2_conf="/etc/grub2-efi.cfg" || grub2_conf="/etc/grub2.cfg"
  printf "$grub2_conf (symlinked to $(readlink $grub2_conf)).\n"
  grub2-mkconfig -o "$grub2_conf"
}

remove_leftovers() {
  # Remove all temporary files and tweaks used during the migration process.
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
  # All function calls.
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
  get_branded_modules
  find_repos_directory
  find_enabled_repos
  grab_gpg_keys
  create_temp_el_repo
  register_to_euroman
  remove_distro_gpg_pubkey
  disable_distro_repos
  fix_oracle_shenanigans
  remove_centos_yum_branding
  force_el_release
  install_el_base
  update_initrd
  el_distro_sync
  debrand_modules
  deal_with_problematic_rpms
  reinstall_all_rpms
  update_grub
  remove_leftovers
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

