#!/bin/bash

while getopts ":p:u:" option; do
    case "$option" in
        p) EUROMAN_CREDENTIALS_PSW="$OPTARG" ;;
        u) EUROMAN_CREDENTIALS_USR="$OPTARG" ;;
        *) echo "Wrong option!" && exit 1
    esac
done

if [ -e /etc/yum.repos.d/el-base.repo ]; then
    echo "This system has local EuroLinux repository configured."
    echo "I won't dregeister it"
    exit 0
else
    echo "Checking python module"
    python -c "import argparse" && echo "module present" || sudo yum install -y https://cbs.centos.org/kojifiles/packages/python-argparse/1.2.1/2.el6/noarch/python-argparse-1.2.1-2.el6.noarch.rpm
    echo "Trying to unregister system"
    sudo /home/vagrant/eurolinux-migration-scripts/euroman/unregister.py -u $EUROMAN_CREDENTIALS_USR -p $EUROMAN_CREDENTIALS_PSW -i $(sudo grep -Eo 'ID-[0-9]*' /etc/sysconfig/rhn/systemid | grep -Eo '[0-9]*')
    sudo rm -f /etc/sysconfig/rhn/systemid
fi