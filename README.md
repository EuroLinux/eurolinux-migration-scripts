# migrate2eurolinux - 'el6-only-switch-repos'

## Switch repos of an Enterprise Linux 6 system to EuroLinux 6

This script will automatically switch repositories of an Enterprise Linux 6
system to EuroLinux 6's, remove only its exclusive packages like eg.
`centos-linux-release` and if installed in EFI mode, install our shim and
update bootloader enteries so our one will be used on next boot.
By default, non-EuroLinux components such as packages from unofficial
repositories will be preserved - take a look at the [Usage](#usage) section for
info on how to make the script remove them and other options.

## Support

The following distributions are supported on the x86_64 architecture:

- CentOS 6
- Red Hat Enterprise Linux 6
- Scientific Linux 6

**If a system has been installed with Secure Boot enabled, make sure that it
is disabled first before running the script.**

## Preparations

The script covers the basics of several Enterprise Linux installations, but it
can't possibly cover every existing non-standard configuration out there.  
Extra precautions have been arranged, but there's always the risk of something
going wrong in the process and users are always recommended to make a backup.  
Make sure you have prepared valid EuroMan credentials, since they'll be
necessary for registering that instance and migrating.  
If your system is registered to a subscription management service, make sure
that all assets such as keys and certificates related to that management
service have been backed up if necessary and that the system has been
unregistered before running the script. The script will attempt to detect a
valid subscription and inform you on the steps required before proceeding if
one is found.  
Make sure that your system does not use any centralized package management
suite. The script will provide EuroLinux repositories, but as of today it has
no knowledge of the suite mentioned - package collisions are likely to happen.
Please disable the suite if necessary before attempting to migrate.  
Check your system if there's a file mounted directly at the directory `/mnt`
or if the directory `/sys` is mounted as read-only. Make sure none of this
applies, otherwise the migration will not succeed. An example of an error is
presented later on.  
If your system has been installed with FIPS Mode enabled, the migration
process will not proceed. In this case, a clean installation is recommended.

## Usage

Clone this repository on the instance you want to migrate (or just upload the
contents of this repository your way there), switch to root account and run the
script as follows:

```bash
bash migrate2eurolinux.sh
```

You can specify several parameters:

- `-f` to skip a warning message about backup recommendation. Necessary for
  running non-interactively.
- `-u` to specify your EuroMan username
- `-p` to specify your EuroMan password
- `-w` to remove all detectable non-EuroLinux components such as packages from
  unofficial repositories, .repo files from your current distribution, etc. 
  rather than preserving them

Sample non-interactive usage:

```bash
bash migrate2eurolinux.sh -f -u 'user@example.com' -p 'password123'
```

Or with debug and additional debug messages logging:

```bash
bash -x migrate2eurolinux.sh -f -u 'user@example.com' -p 'password123' | tee -a migration_debug.log
```

