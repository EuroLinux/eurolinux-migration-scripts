# WIP: eurolinux-migration-scripts

**Work in Progress**.

To migrate:

- [ ] vagrant based test machines
- [ ] at least public test sets
- [ ] documentation

## Migrating to EuroLinux 7

Right now migration to EuroLinux 7 from other Enterprise Linux 7 distro is
possible with the script from this repository only **if you have a locally
mirrored EuroLinux repository**.

To migrate, clone the git repository first:
```
git clone https://github.com/EuroLinux/eurolinux-migration-scripts
cd eurolinux-migration-scripts
```

Then edit the script by modifying the `set_repos` function - you must replace
the `TODO-FIXME` placeholders with the URLs of your locally mirrored
repositories and remove the `exit 1` line - a precaution that ensures you've
modified the function.
(alternatively comment out it being called on the bottom of the script)
```
# Change 'vi' to the text editor of your choice 
vi migrate_to_el7.sh
```

Make sure to run the script with superuser privileges:
```bash
sudo ./migrate_to_el7.sh
```

If you want to run without full migration (reinstalling already installed
packages), export the `DISABLE_FULL_MIGRATION` variable with any value.
Example:
```bash
export DISABLE_FULL_MIGRATION=1
sudo ./migrate_to_el7.sh
```

## Migrating to EuroLinux 8

Work in progress - it will be published in a short time.

## Considerations

- Please make a backup before running any migration scripts
- The *complete migration* reinstalls the `filesystem` package. If you are using an ISO as a locally mounted repository, the ISO should **not** be mounted at the `/mnt` directory.
