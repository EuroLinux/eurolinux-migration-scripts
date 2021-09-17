# migrate2eurolinux

## Switch from an Enterprise Linux flavor to EuroLinux

This script will automatically switch an Enterprise Linux system to EuroLinux
by removing any that-system-specific packages or replacing them with the
EuroLinux equivalent.

## Support

The following distributions are supported on the x86_64 architecture:
- AlmaLinux 8
- CentOS 7
- CentOS 8
- Oracle Linux 7
- Oracle Linux 8
- Red Hat Enterprise Linux 7
- Rocky Linux 8
- Scientific Linux 7

## Preparations

The script covers the basics of several Enterprise Linux installations but it
can't possible cover every existing non-standard configuration out there.  
Extra precautions have been arranged but there's always the risk of something
going wrong in the process and users are always recommended to make a backup.  
If your system release is lower than 8, make sure you have prepared valid
EuroMan credentials since they'll be necessary for registering that instance
and migrating.

## Usage

Clone this repository on the instance you want to migrate (or just upload the
raw script there), switch to root account and run the script as follows:

```
bash migrate2eurolinux.sh
```

You can specify several parameters:

- `-f` to skip a warning message about backup recommendation. Necessary for running non-interactively.
- `-u` to specify your EuroMan username
- `-p` to specify your EuroMan password

EuroMan is applicable only to releases lower than 8 and if the credentials will
be provided on release 8, the script won't use them.

Sample non-interactive usage:

```
bash migrate2eurolinux.sh -f -u 'user@example.com' -p 'password123'
```

Or with debug and additional debug messages logging:

```
bash -x migrate2eurolinux.sh -f -u 'user@example.com' -p 'password123' | tee -a migration_debug.log
```
