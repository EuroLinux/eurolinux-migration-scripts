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

The distributions must be up to date and only their latest minor release is
supported.

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

- `-b` to preserve several non-EuroLinux components such as packages from
  unofficial repositories, disabled and backed-up .repo files from your
  current distribution, etc. rather than cleaning them up.
- `-f` to skip a warning message about backup recommendation. Necessary for
  running non-interactively.
- `-u` to specify your EuroMan username
- `-p` to specify your EuroMan password
- `-r` to use your custom .repo file which points to your own local EuroLinux
  mirror

EuroMan is applicable only to releases lower than 8 and if the credentials are
provided for release 8, the script won't use them. The same applies when using
the `-r` option since it's assumed that you have a valid registration if you
appear to have EuroLinux packages mirrored locally.

Sample non-interactive usage:

```bash
bash migrate2eurolinux.sh -f -u 'user@example.com' -p 'password123'
```

Or with debug and additional debug messages logging:

```bash
bash -x migrate2eurolinux.sh -f -u 'user@example.com' -p 'password123' | tee -a migration_debug.log
```

### Removing distro-provided kernel

Once the script has finished, there will still be a distro-provided kernel
running and maybe some other ones if you ran the script with the `-b` option -
especially those installed from third-party repositories. In order to remove
it and related packages such as *kernel-devel*, *kernel-headers*, etc. an
additional script has been created: *remove_kernels.sh*.

The script will be launched automatically if a system has already successfully
migrated to EuroLinux. The default behavior is to remove everything that is not
provided by EuroLinux but if running manually, the user can specify, if they
want to remove only the kernels their old distro provided or all non-EuroLinux
kernels and related packages - those from third-party repositories among
others. Or if they want to perform a dry-run for listing, what would happen.

Once the answer is present, a systemd service will be created and enabled - it
will remove the specified packages on next system boot, perform a bootloader
update and disable itself to ensure no leftovers are present.

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

