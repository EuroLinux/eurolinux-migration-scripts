# migrate2eurolinux

## Switch from an Enterprise Linux system to EuroLinux

This script will automatically switch an Enterprise Linux system to EuroLinux
by removing any that-system-specific packages or replacing them with EuroLinux
equivalents.

## Support

The following distributions are supported on the x86_64 architecture:
- AlmaLinux 8
- CentOS 7
- CentOS 8
- Oracle Linux 7
- Oracle Linux 8
- Red Hat Enterprise Linux 7
- Red Hat Enterprise Linux 8
- Rocky Linux 8
- Scientific Linux 7

## Preparations

The script covers the basics of several Enterprise Linux installations but it
can't possibly cover every existing non-standard configuration out there.  
Extra precautions have been arranged but there's always the risk of something
going wrong in the process and users are always recommended to make a backup.  
If your system release is lower than 8, make sure you have prepared valid
EuroMan credentials since they'll be necessary for registering that instance
and migrating.

## Usage

Clone this repository on the instance you want to migrate (or just upload the
raw script there), switch to root account and run the script as follows:

```bash
bash migrate2eurolinux.sh
```

You can specify several parameters:

- `-f` to skip a warning message about backup recommendation. Necessary for
  running non-interactively.
- `-u` to specify your EuroMan username
- `-p` to specify your EuroMan password

EuroMan is applicable only to releases lower than 8 and if the credentials are
provided for release 8, the script won't use them.

Sample non-interactive usage:

```bash
bash migrate2eurolinux.sh -f -u 'user@example.com' -p 'password123'
```

Or with debug and additional debug messages logging:

```bash
bash -x migrate2eurolinux.sh -f -u 'user@example.com' -p 'password123' | tee -a migration_debug.log
```

## Tests

Tests related to proper system functionality have been provided. There's a
*tests* directory that contains some of our tools that assist us with running
the tests on Vagrant boxes and contains a *EL-core-functional-tests* directory
with the actual tests.
*EL-core-functional-tests* is a distinct responsibility to
*eurolinux-migration-scripts* and you should refer to [that
project](https://github.com/EuroLinux/EL-core-functional-tests)'s
documentation when running on e.g. bare-metal production machines.

### Running the tests

There's a *Vagrantfile* that contains the specification of several systems
that can be quickly spawned for performing a migration to EuroLinux and
testing their operational functionality after the migration. 

A quick way for running all the tests on Vagrant virtual machines is to run a
command like this on your host machine:

```bash
./tests/wrapper.sh -b centos7 centos8
```

Once a migration has been performed on your CentOS 7 and 8 virtual machines,
this example will run all the tests in these machines and log the testing
sessions on your host machine.  
Refer to the comments the scripts provide for additional information.

