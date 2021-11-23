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

It is possible to migrate from other release versions such as 8.2 since the
script should succeed in syncing the packages to EuroLinux equivalents but it's
not officially supported. Analogically a migration from 7.4 upwards should
succeed in syncing to EuroLinux 7.9.  
**If a system has been installed with Secure Boot enabled, make sure that it
is disabled first before running the script.**

## Preparations

The script covers the basics of several Enterprise Linux installations but it
can't possibly cover every existing non-standard configuration out there.  
Extra precautions have been arranged but there's always the risk of something
going wrong in the process and users are always recommended to make a backup.  
If your system release is lower than 8, make sure you have prepared valid
EuroMan credentials since they'll be necessary for registering that instance
and migrating.  
If your system is registered to a subscription management service, make sure
that all assets such as keys and certificates related to that management
service have been backed up if necessary and that the system has been
unregistered before running the script. The script will attempt to detect a
valid subscription and inform you on the steps required before proceeding if
one is found.  
Make sure that your system does not use any centralized package management
suite. The script will provide EuroLinux repositories but as of today it has
no knowledge of the suite mentioned - package collisions are likely to happen.
Please disable the suite if necessary before attempting to migrate.  
Check your system if there's a file mounted directly at the directory `/mnt`
or if the directory `/sys` is mounted as read-only. Make sure none of this
applies, otherwise the migration will not succeed. An example of an error is
presented later on. 
You system may have custom kernel modules installed. If they are managed
by DKMS and your package manager takes care of this, they will most
likely be available out-of-the-box after the migration succeeds. Still
it's recommended that a manual verification be performed. Modules
installed manually (e.g. from a *.run* installer) will most likely have
to be installed again the same way.  
If your system has been installed with FIPS Mode enabled, the migration
will not succeed. It might look like everything's fine but you'll
encounter a kernel panic once the system is rebooted. In this case a
clean installation is recommended.

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
- `-r` to use your custom .repo file which points to your own local EuroLinux
  mirror
- `-w` to remove all detectable non-EuroLinux components such as packages from
  unofficial repositories, .repo files from your current distribution, etc. 
  rather than preserving them

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
running (assuming that's the one being in use when running the migration
script) and maybe some other ones if you ran the script without the `-w` option
- especially those installed from third-party repositories. In order to remove
  it and related packages such as *kernel-devel*, *kernel-headers*, etc. an
additional script has been created: *remove_kernels.sh*.

The script will be launched automatically if a system has already successfully
migrated to EuroLinux. That **standalone script's** default behavior is to
remove everything that is not provided by EuroLinux but if running manually or
via migrate2linux.sh with the `-w` option, the user can specify, if they want
to remove only the kernels their old distro provided or all non-EuroLinux
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

## Offline migration

The script supports specifying one's own mirror with EuroLinux repositories
with the `-r` option that points to one's .repo file. It is assumed that the
mirrors have been created with [our official
guide](https://docs.euro-linux.com/HowTo/mirror-eurolinux-locally/) and
perhaps [an ISO image has been
created](https://docs.euro-linux.com/HowTo/create-iso-with-repositories/) as
well. Still, this might not be the case since there are multiple possibilities
of implementing the internal mirror such as an HTTP server in a company's
intranet. It's up to the user to decide on the implementation but just in case
an ISO image is created, it can be used along with the Vagrant-based
infrastructure for prototyping before applying the same procedure on
production machines.  
If libvirt is used as Vagrant provider, simply uncomment the following
snippet and adjust the ISO image path:
```ruby
  #  libvirt.storage :file, :device => :cdrom, :path => "/var/lib/libvirt/images/mirror.iso"
```

## Troubleshooting

### The 'filesystem' package installation fails

The migration fails with a message like this:
```
Failed:
  filesystem.x86_64 0:3.2-25.el7
```

or:
```
Failed:
  filesystem-3.8-3.el8.x86_64                         filesystem-3.8-3.el8.x86_64

Error: Transaction failed
```

Most likely you performed an offline migration with an ISO image (or a
different file) mounted directly at */mnt*. Make sure that only its
subdirectories are used as mount points.
