def erecipients = "devel@euro-linux.com"
def ebody = """
${currentBuild.fullDisplayName} / ${currentBuild.number}
Check url: ${currentBuild.absoluteUrl}.
"""

def supported_9_machine_names = ["almalinux9", "generic-rhel9", "oracle9", "rockylinux9"]
def supported_8_machine_names = ["almalinux8", "centos8-5", "generic-rhel8", "oracle8", "rockylinux8"]
def supported_7_machine_names = ["centos7", "generic-rhel7", "oracle7", "scientific7"]

pipeline {
    agent {
        node {
          label 'libvirt'
        }
    }
    environment {
        EUROMAN_CREDENTIALS = credentials('EUROMAN_CREDENTIALS')
    }
    stages {
        stage("Migrate supported systems to EuroLinux 9"){
            steps{
                catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
                  script{
                      parallel supported_9_machine_names.collectEntries { vagrant_machine -> [ "${vagrant_machine}": {
                              stage("$vagrant_machine") {
                                  sleep(5 * Math.random())
                                  sh("vagrant destroy $vagrant_machine -f")
                                  sh("vagrant up $vagrant_machine")
                                  sh("vagrant ssh $vagrant_machine -c 'sudo /home/vagrant/eurolinux-migration-scripts/check_redhat_assets.sh -b'")
                                  sh("vagrant ssh $vagrant_machine -c 'sudo /home/vagrant/eurolinux-migration-scripts/migrate2eurolinux.sh -f -v -w'")
                                  sh("vagrant ssh $vagrant_machine -c 'sudo reboot' || true")
                                  sleep(300)
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
        stage("Migrate supported systems to EuroLinux 8"){
            steps{
                catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
                  script{
                      parallel supported_8_machine_names.collectEntries { vagrant_machine -> [ "${vagrant_machine}": {
                              stage("$vagrant_machine") {
                                  sleep(5 * Math.random())
                                  sh("vagrant destroy $vagrant_machine -f")
                                  sh("vagrant up $vagrant_machine")
                                  sh("vagrant ssh $vagrant_machine -c 'sudo /home/vagrant/eurolinux-migration-scripts/check_redhat_assets.sh -b'")
                                  sh("vagrant ssh $vagrant_machine -c 'sudo /home/vagrant/eurolinux-migration-scripts/migrate2eurolinux.sh -f -v -w'")
                                  sh("vagrant ssh $vagrant_machine -c 'sudo reboot' || true")
                                  sleep(300)
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
                                  sleep(5 * Math.random())
                                  sh("vagrant destroy $vagrant_machine -f")
                                  sh("vagrant up $vagrant_machine")
                                  sh("vagrant ssh $vagrant_machine -c 'sudo /home/vagrant/eurolinux-migration-scripts/check_redhat_assets.sh -b'")
                                  sh("vagrant ssh $vagrant_machine -c 'sudo /home/vagrant/eurolinux-migration-scripts/migrate2eurolinux.sh -f -v -w -u $EUROMAN_CREDENTIALS_USR -p $EUROMAN_CREDENTIALS_PSW'")
                                  sh("vagrant ssh $vagrant_machine -c 'sudo reboot' || true")
                                  sleep(300)
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
        stage("Migrate supported systems to EuroLinux 9 and preserve non-EuroLinux packages"){
            steps{
                catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
                  script{
                      parallel supported_9_machine_names.collectEntries { vagrant_machine -> [ "${vagrant_machine}": {
                              stage("$vagrant_machine") {
                                  sleep(5 * Math.random())
                                  sh("vagrant destroy $vagrant_machine -f")
                                  sh("vagrant up $vagrant_machine")
                                  sh("vagrant ssh $vagrant_machine -c 'sudo /home/vagrant/eurolinux-migration-scripts/check_redhat_assets.sh -b'")
                                  sh("vagrant ssh $vagrant_machine -c 'sudo /home/vagrant/eurolinux-migration-scripts/migrate2eurolinux.sh -f -v'")
                                  sh("vagrant ssh $vagrant_machine -c 'sudo reboot' || true")
                                  sleep(300)
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
        stage("Migrate supported systems to EuroLinux 8 and preserve non-EuroLinux packages"){
            steps{
                catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
                  script{
                      parallel supported_8_machine_names.collectEntries { vagrant_machine -> [ "${vagrant_machine}": {
                              stage("$vagrant_machine") {
                                  sleep(5 * Math.random())
                                  sh("vagrant destroy $vagrant_machine -f")
                                  sh("vagrant up $vagrant_machine")
                                  sh("vagrant ssh $vagrant_machine -c 'sudo /home/vagrant/eurolinux-migration-scripts/check_redhat_assets.sh -b'")
                                  sh("vagrant ssh $vagrant_machine -c 'sudo /home/vagrant/eurolinux-migration-scripts/migrate2eurolinux.sh -f -v'")
                                  sh("vagrant ssh $vagrant_machine -c 'sudo reboot' || true")
                                  sleep(300)
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
                                  sleep(5 * Math.random())
                                  sh("vagrant destroy $vagrant_machine -f")
                                  sh("vagrant up $vagrant_machine")
                                  sh("vagrant ssh $vagrant_machine -c 'sudo /home/vagrant/eurolinux-migration-scripts/check_redhat_assets.sh -b'")
                                  sh("vagrant ssh $vagrant_machine -c 'sudo /home/vagrant/eurolinux-migration-scripts/migrate2eurolinux.sh -f -v -u $EUROMAN_CREDENTIALS_USR -p $EUROMAN_CREDENTIALS_PSW'")
                                  sh("vagrant ssh $vagrant_machine -c 'sudo reboot' || true")
                                  sleep(300)
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
