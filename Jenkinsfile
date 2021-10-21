def machine_names = ["almalinux8", "centos7", "centos8", "oracle7", "oracle8", "rhel7", "rockylinux8", "scientific7"]

pipeline {
    agent {
        node {
          label 'libvirt'
        }
    }
    environment {
        EUROMAN_CREDENTIALS = credentials('53f788db-5d13-45de-9f1a-a142f8400e77')
        VAGRANT_BOX_RHEL7_URL = credentials('VAGRANT_BOX_RHEL7_URL')
    }
    stages {
        stage("Migrate supported systems on Vagrant machines to EuroLinux"){
            steps{
                script{ 
                    parallel machine_names.collectEntries { vagrant_machine -> [ "${vagrant_machine}": {
                            stage("$vagrant_machine") {
                                sh("vagrant destroy $vagrant_machine -f")
                                sh("vagrant up $vagrant_machine")
                                sh("vagrant ssh $vagrant_machine -c \"sudo /vagrant/migrate2eurolinux.sh -f -v -u $EUROMAN_CREDENTIALS_USR -p $EUROMAN_CREDENTIALS_PSW && sudo reboot\" || true")
                                sh("echo 'Waiting 5 minutes for the box to warm up and for the kernel-removing systemd service to finish its job...'")
                                sh("sleep 300")
                                sh("vagrant ssh $vagrant_machine -c 'sudo /vagrant/test_what_non_el_remains_after_migration.sh'")
                                sh("vagrant destroy $vagrant_machine -f")
                            }
                        }]
                    }
                }
            }
        }
    }
}