#!/bin/bash
#
# name: migrate_to_el7.sh
#
# description: Migrates existing {RHEL,OL,CentOS,Scientific Linux} installation to EuroLinux
# default log file: /var/log/eurolinux_migration.log
#
# Copyright 2016-2021 EuroLinux, Inc.
# Aleksander Baranowski <ab@euro-linux.com>
# Cezary Drak <cd@euro-linux.com>
# Jakub Olczyk <jwo@euro-linux.com>

# Stop on first error, not declared variable or failed pipe
set -eo pipefail


# Using MY_ in order to avoid any collision.
MY_LOGFILE="/var/log/eurolinux_migration.log"

check_root_privilages(){
    if [[ "$(id -u)" != 0 ]] ; then
        echo "Please run with superuser privilages."
        exit 1
    fi
    echo -e "\nStarted $0 at $(date)"  | tee -a $MY_LOGFILE
}

dump_rpms(){
    # This is case that we need to manualy revert changes, also useful for debuging
    echo "DUMPING installed RPMS:" | tee -a $MY_LOGFILE
    rpm -qa | tee -a $MY_LOGFILE
}

set_repos(){
    #
    # You have to manually fill cat command below
    # baseurl is well url :) examples:
    # baseurl=http://my.local.repository/dist/eurolinux/7/x86_64/os
    # baseurl=http://my.local.repository/dist/eurolinux/7/x86_64/updates
    # baseurl=file:///iso/eurolinux-os-7/
    # baseurl=file:///iso/eurolinux-updates-7/
    # After fixing remove this save switch
    echo "Fix repos and remove this and the next line (one with 'exit 1')"
    exit 1
    cat<< EOF > /etc/yum.repos.d/eurolinux.repo
[base-os]
name=EuroLinux 7 Base
baseurl=TODO-FIXME
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-eurolinux7

[base-updates]
name=EuroLinux 7 Updates
baseurl=TODO-FIXME
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-eurolinux7
EOF

}

change_release(){
    echo "Checking if el-release is available"
    yum info el-release
    echo "Checking of package to provide system release"
    sys_release=$(rpm -q --whatprovides redhat-release)
    if [ -z "$sys_release" ]; then
        echo "I'm unable to find system-release is your distribution supported?"
        exit 1
    fi
    if [ "$(echo "$sys_release" | wc -l)" -ne 1 ]; then
        echo "Sorry there are multiple packages that point to system-release manual intervention is required:"
        echo "Packages: "
        echo "$sys_release"
        exit 1
    fi

    case "$sys_release" in
        redhat-release*|centos-release*|sl-release*|oraclelinux-release*|enterprise-release*)
            echo "Found supported distro!" ;;
        el-release*|eurolinux-release*)
            echo "Your distribution seems to be already migrated to EuroLinux :)!"
            echo "Exiting with 0 status"
            exit 0
            ;;
        *)  "You appear to be running an unsupported distribution.: sys_release" ;;
    esac
    # Extra steps
    case "$sys_release" in
        redhat-release*)
            # RHEL has separate EULA file
            echo "Removing Red Hat EULA"
            if rpm -q --whatprovides redhat-release-eula; then
                eula_release=$(rpm -q --whatprovides redhat-release-eula)
                rpm -f -e --nodeps "$eula_release" | tee -a $MY_LOGFILE 
            fi ;;
        *)  echo "No need to remove EULA extra separate package" ;;
    esac
    echo "Removing $sys_release"
    rpm -e --nodeps "$sys_release" | tee -a $MY_LOGFILE
    echo "Install el-release"
    yum install -y --nogpgcheck el-release
}

full_migration(){
    set +u
    if [ -z "$DISABLE_FULL_MIGRATION" ]; then
        echo "Reinstalling system packages"
        yum reinstall -y '*' --skip-broken
    fi
    set -u
}

check_root_privilages
set_repos
dump_rpms
change_release
full_migration
