def machine_names = ["almalinux8", "centos8", "oracle8", "rockylinux8"]

pipeline {
    agent {
        node {
          label 'libvirt'
        }
    }
    stages {
        stage("Migrate supported systems on Vagrant machines to EuroLinux"){
            steps{
                script{ 
                    parallel machine_names.collectEntries { vagrant_machine -> [ "${vagrant_machine}": {
                            stage("$vagrant_machine") {
                                sh("vagrant ssh $vagrant_machine -c 'sudo /vagrant/migrate2eurolinux.sh -f -v && sudo reboot' || true")
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
