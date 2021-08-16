# WIP: eurolinux-migration-scripts

**Work in Progress**.

To migrate:

- [] vagrant based test machines
- [] at least public test sets
- [] documentation

## Migrating to EuroLinux 7

Right now migration to EuroLinux 7, from other Enterprise Linux 7, with scripts
that are in this repository, is only possible **if you have a locally mirrored
EuroLinux repository**.

To migrate, firstly clone the git repository.

```
git clone https://github.com/EuroLinux/eurolinux-migration-scripts
cd eurolinux-migration-scripts
```

Then fill the `set_repos` function or comment its invocation on the bottom of
the script.

To run full system migration:

```bash
sudo ./migrate_to_el7.sh
```

If you want to run without full migration, export the `DISABLE_FULL_MIGRATION`
variable with any value. Example:

```bash
export DISABLE_FULL_MIGRATION=1
sudo ./migrate_to_el7.sh
```

## Migrating to EuroLinux 8

Work in progress - it will be published in a short time.

## Considerations

- Please make a backup before running migration scripts
- If you are using ISO as a locally mounted repository, the complete migration
  reinstalls the `filesystem` package the ISO should not be mounted to the
  `/mnt` directory.
