# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box_check_update = false
  config.vm.synced_folder '.', '/vagrant', type: "rsync"

  config.vm.define "almalinux8" do |i|
    i.vm.box = "eurolinux-vagrant/almalinux-8"
    i.vm.hostname = "almalinux8"
  end

  config.vm.define "centos7" do |i|
    i.vm.box = "eurolinux-vagrant/centos-7"
    i.vm.hostname = "centos7"
  end

  config.vm.define "centos8" do |i|
    i.vm.box = "eurolinux-vagrant/centos-8"
    i.vm.hostname = "centos8"
  end

  config.vm.define "oracle7" do |i|
    i.vm.box = "eurolinux-vagrant/oracle-linux-7"
    i.vm.hostname = "oracle7"
  end

  config.vm.define "oracle8" do |i|
    i.vm.box = "eurolinux-vagrant/oracle-linux-8"
    i.vm.hostname = "oracle8"
  end

  config.vm.define "rhel7" do |i|
    i.vm.box = "rhel7"
    i.vm.box_download_insecure = true
    i.vm.box_url = ENV['VAGRANT_BOX_RHEL7_URL']
    i.vm.hostname = "rhel7"
  end

  #config.vm.define "rhel8" do |i|
  #  i.vm.box = #"redacted"
  #  i.vm.hostname = "rhel8"
  #end

  config.vm.define "rockylinux8" do |i|
    i.vm.box = "eurolinux-vagrant/rocky-8"
    i.vm.hostname = "rockylinux8"
  end

  config.vm.define "scientific7" do |i|
    i.vm.box = "eurolinux-vagrant/scientific-linux-7"
    i.vm.hostname = "scientific7"
  end

end
