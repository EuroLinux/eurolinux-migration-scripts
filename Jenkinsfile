def erecipients = "devel@euro-linux.com"
def ebody = """
${currentBuild.fullDisplayName} / ${currentBuild.number}
Check url: ${currentBuild.absoluteUrl}.
"""

def supported_8_machine_names = ["almalinux8", "centos8", "generic-rhel8", "oracle8", "rhel8", "rockylinux8"]
def legacy_8_machine_names = ["almalinux8-4", "centos8-4", "rockylinux8-4"]
def supported_7_machine_names = ["centos7", "generic-rhel7", "oracle7", "rhel7", "scientific7"]

pipeline {
    agent {
        node {
          label 'libvirt'
        }
    }
    environment {
        EUROMAN_CREDENTIALS = credentials('EUROMAN_CREDENTIALS')
        VAGRANT_BOX_RHEL7_URL = credentials('VAGRANT_BOX_RHEL7_URL')
        VAGRANT_BOX_RHEL8_URL = credentials('VAGRANT_BOX_RHEL8_URL')
    }
    stages {
        stage("Migrate supported systems to EuroLinux 8"){
            steps{
                catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
                  script{
                      parallel supported_8_machine_names.collectEntries { vagrant_machine -> [ "${vagrant_machine}": {
                              stage("$vagrant_machine") {
                                  sh("vagrant destroy $vagrant_machine -f")
                                  sh("vagrant up $vagrant_machine")
                                  sh("vagrant ssh $vagrant_machine -c 'sudo /home/vagrant/eurolinux-migration-scripts/check_redhat_assets.sh -b'")
                                  sh("vagrant ssh $vagrant_machine -c \"sudo /home/vagrant/eurolinux-migration-scripts/migrate2eurolinux.sh -f -v -w && sudo reboot\" || true")
                                  sh("echo 'Waiting 5 minutes for the box to warm up and for the kernel-removing systemd service to finish its job...'")
                                  sh("sleep 300")
                                  sh("vagrant ssh $vagrant_machine -c 'sudo /home/vagrant/eurolinux-migration-scripts/test_what_non_el_remains_after_migration.sh'")
                                  sh("vagrant ssh $vagrant_machine -c 'sudo /home/vagrant/eurolinux-migration-scripts/check_redhat_assets.sh -a'")
                                  sh("vagrant destroy $vagrant_machine -f")
                              }
                          }]
                      }
                  }
                }
            }
        }
        stage("Migrate supported systems to EuroLinux 7"){
            steps{
                catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
                  script{
                      parallel supported_7_machine_names.collectEntries { vagrant_machine -> [ "${vagrant_machine}": {
                              stage("$vagrant_machine") {
                                  sh("vagrant destroy $vagrant_machine -f")
                                  sh("vagrant up $vagrant_machine")
                                  sh("vagrant ssh $vagrant_machine -c 'sudo /home/vagrant/eurolinux-migration-scripts/check_redhat_assets.sh -b'")
                                  sh("vagrant ssh $vagrant_machine -c \"sudo /home/vagrant/eurolinux-migration-scripts/migrate2eurolinux.sh -f -v -w -u $EUROMAN_CREDENTIALS_USR -p $EUROMAN_CREDENTIALS_PSW && sudo reboot\" || true")
                                  sh("echo 'Waiting 5 minutes for the box to warm up and for the kernel-removing systemd service to finish its job...'")
                                  sh("sleep 300")
                                  sh("vagrant ssh $vagrant_machine -c 'sudo /home/vagrant/eurolinux-migration-scripts/test_what_non_el_remains_after_migration.sh'")
                                  sh("vagrant ssh $vagrant_machine -c 'sudo /home/vagrant/eurolinux-migration-scripts/check_redhat_assets.sh -a'")
                                  sh("vagrant destroy $vagrant_machine -f")
                              }
                          }]
                      }
                  }
                }
            }
        }
        stage("Migrate legacy systems to equivalent legacy minor EuroLinux 8"){
            steps{
                catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
                  script{
                      parallel legacy_8_machine_names.collectEntries { vagrant_machine -> [ "${vagrant_machine}": {
                              stage("$vagrant_machine") {
                                  sh("vagrant destroy $vagrant_machine -f")
                                  sh("vagrant up $vagrant_machine")
                                  sh("vagrant ssh $vagrant_machine -c 'sudo /home/vagrant/eurolinux-migration-scripts/check_redhat_assets.sh -b'")
                                  sh("vagrant ssh $vagrant_machine -c \"sudo /home/vagrant/eurolinux-migration-scripts/migrate2eurolinux.sh -r /home/vagrant/eurolinux-migration-scripts/vault.repo -f -v -w && sudo reboot\" || true")
                                  sh("echo 'Waiting 5 minutes for the box to warm up and for the kernel-removing systemd service to finish its job...'")
                                  sh("sleep 300")
                                  sh("vagrant ssh $vagrant_machine -c 'sudo /home/vagrant/eurolinux-migration-scripts/test_what_non_el_remains_after_migration.sh'")
                                  sh("vagrant ssh $vagrant_machine -c 'sudo /home/vagrant/eurolinux-migration-scripts/check_redhat_assets.sh -a'")
                                  sh("vagrant destroy $vagrant_machine -f")
                              }
                          }]
                      }
                  }
                }
            }
        }
        stage("Migrate supported systems to EuroLinux 8 and preserve non-EuroLinux packages"){
            steps{
                catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
                  script{
                      parallel supported_8_machine_names.collectEntries { vagrant_machine -> [ "${vagrant_machine}": {
                              stage("$vagrant_machine") {
                                  sh("vagrant destroy $vagrant_machine -f")
                                  sh("vagrant up $vagrant_machine")
                                  sh("vagrant ssh $vagrant_machine -c 'sudo /home/vagrant/eurolinux-migration-scripts/check_redhat_assets.sh -b'")
                                  sh("vagrant ssh $vagrant_machine -c \"sudo /home/vagrant/eurolinux-migration-scripts/migrate2eurolinux.sh -f -v && sudo reboot\" || true")
                                  sh("echo 'Waiting 5 minutes for the box to warm up and for the kernel-removing systemd service to finish its job...'")
                                  sh("sleep 300")
                                  sh("vagrant ssh $vagrant_machine -c 'sudo /home/vagrant/eurolinux-migration-scripts/test_what_non_el_remains_after_migration.sh -t'")
                                  sh("vagrant ssh $vagrant_machine -c 'sudo /home/vagrant/eurolinux-migration-scripts/check_redhat_assets.sh -a' || true")
                                  sh("vagrant destroy $vagrant_machine -f")
                              }
                          }]
                      }
                  }
                }
            }
        }
        stage("Migrate supported systems to EuroLinux 7 and preserve non-EuroLinux packages"){
            steps{
                catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
                  script{
                      parallel supported_7_machine_names.collectEntries { vagrant_machine -> [ "${vagrant_machine}": {
                              stage("$vagrant_machine") {
                                  sh("vagrant destroy $vagrant_machine -f")
                                  sh("vagrant up $vagrant_machine")
                                  sh("vagrant ssh $vagrant_machine -c 'sudo /home/vagrant/eurolinux-migration-scripts/check_redhat_assets.sh -b'")
                                  sh("vagrant ssh $vagrant_machine -c \"sudo /home/vagrant/eurolinux-migration-scripts/migrate2eurolinux.sh -f -v -u $EUROMAN_CREDENTIALS_USR -p $EUROMAN_CREDENTIALS_PSW && sudo reboot\" || true")
                                  sh("echo 'Waiting 5 minutes for the box to warm up and for the kernel-removing systemd service to finish its job...'")
                                  sh("sleep 300")
                                  sh("vagrant ssh $vagrant_machine -c 'sudo /home/vagrant/eurolinux-migration-scripts/test_what_non_el_remains_after_migration.sh -t'")
                                  sh("vagrant ssh $vagrant_machine -c 'sudo /home/vagrant/eurolinux-migration-scripts/check_redhat_assets.sh -a' || true")
                                  sh("vagrant destroy $vagrant_machine -f")
                              }
                          }]
                      }
                  }
                }
            }
        }
        stage("Migrate legacy systems to equivalent legacy minor EuroLinux 8 and preserve non-EuroLinux packages"){
            steps{
                catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
                  script{
                      parallel legacy_8_machine_names.collectEntries { vagrant_machine -> [ "${vagrant_machine}": {
                              stage("$vagrant_machine") {
                                  sh("vagrant destroy $vagrant_machine -f")
                                  sh("vagrant up $vagrant_machine")
                                  sh("vagrant ssh $vagrant_machine -c 'sudo /home/vagrant/eurolinux-migration-scripts/check_redhat_assets.sh -b'")
                                  sh("vagrant ssh $vagrant_machine -c \"sudo /home/vagrant/eurolinux-migration-scripts/migrate2eurolinux.sh -r /home/vagrant/eurolinux-migration-scripts/vault.repo -f -v && sudo reboot\" || true")
                                  sh("echo 'Waiting 5 minutes for the box to warm up and for the kernel-removing systemd service to finish its job...'")
                                  sh("sleep 300")
                                  sh("vagrant ssh $vagrant_machine -c 'sudo /home/vagrant/eurolinux-migration-scripts/test_what_non_el_remains_after_migration.sh -t'")
                                  sh("vagrant ssh $vagrant_machine -c 'sudo /home/vagrant/eurolinux-migration-scripts/check_redhat_assets.sh -a' || true")
                                  sh("vagrant destroy $vagrant_machine -f")
                              }
                          }]
                      }
                  }
                }
            }
        }
    }
    post {
        success {
            echo 'Pipeline finished'
        }
        failure {
            echo 'Pipeline failed'
                mail to: erecipients,
                     subject: "Pipeline failed: ${currentBuild.fullDisplayName}",
                     body: ebody
        }
        always {
            echo 'Running "vagrant destroy -f"'
            sh("vagrant destroy -f")
            cleanWs()
        }
    }
}
