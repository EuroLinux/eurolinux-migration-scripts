# migrate2eurolinux with Ansible
## Switch from an Enterprise Linux system to EuroLinux using Ansible playbook (online migration only)
Download this playbook on the Ansible host:

```
curl -L -O https://github.com/EuroLinux/eurolinux-migration-scripts/raw/master/ansible/migrate2eurolinux.yml
```  

Run the playbook as follows:

```
ansible-playbook -i inventory.ini migrate2eurolinux.yml -l <host(s)>
```

By default the script runs with script_opts="-f". If you want to change this, adjust the script_opts variable at the beginning of a playbook.
