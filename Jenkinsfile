def machine_names = ["almalinux8", "centos8", "oracle8", "rockylinux8"]

pipeline {
    agent any
    stages {
        stage("Migrate supported systems on Vagrant machines to EuroLinux"){
            steps{
                script{ 
                    parallel machine_names.collectEntries { vagrant_machine -> [ "${vagrant_machine}": {
                            stage("$vagrant_machine") {
                                vagrant up "$vagrant_machine"
                                vagrant ssh "$vagrant_machine" -c "sudo /vagrant/migrate2eurolinux.sh -f -v && sudo reboot" || true #apparently rebooting counts as a failure
                                echo "Waiting 5 minutes for the box to warm up and for the kernel-removing systemd service to finish its job..."
                                sleep 300
                                vagrant ssh "$vagrant_machine" -c "sudo /vagrant/test_what_non_el_remains_after_migration.sh"
                                vagrant destroy "$vagrant_machine" -f
                            }
                        }]
                    }
                }
            }
        }
    }
}
