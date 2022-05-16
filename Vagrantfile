# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box_check_update = true

  # Disable the builtin syncing functionality and use a file provisioner
  # instead. This allows us to use RHEL boxes that do not come with rsync or
  # other easy ways of getting the files into a box.
  config.vm.synced_folder '.', '/vagrant', disabled: true
  config.vm.provision :file, source: File.expand_path('../', __FILE__), destination: '/home/vagrant/eurolinux-migration-scripts'

  config.vm.provider "libvirt" do |libvirt|
    libvirt.random_hostname = true
  #  libvirt.storage :file, :device => :cdrom, :path => "/var/lib/libvirt/images/mirror.iso"
  end

  config.vm.define "almalinux9" do |i|
    i.vm.box = "eurolinux-vagrant/almalinux-9"
    i.vm.hostname = "almalinux9"
  end

  config.vm.define "almalinux8-4" do |i|
    i.vm.box = "eurolinux-vagrant/almalinux-8"
    i.vm.hostname = "almalinux8-4"
    i.vm.box_version = "8.4.4"
  end

  config.vm.define "almalinux8-5" do |i|
    i.vm.box = "eurolinux-vagrant/almalinux-8"
    i.vm.hostname = "almalinux8-5"
    i.vm.box_version = "8.5.11"
  end

  config.vm.define "almalinux8-6" do |i|
    i.vm.box = "eurolinux-vagrant/almalinux-8"
    i.vm.hostname = "almalinux8-6"
    i.vm.box_version = "8.6.0"
  end

  config.vm.define "almalinux8" do |i|
    i.vm.box = "eurolinux-vagrant/almalinux-8"
    i.vm.hostname = "almalinux8"
  end

  config.vm.define "centos7" do |i|
    i.vm.box = "eurolinux-vagrant/centos-7"
    i.vm.hostname = "centos7"
  end

  config.vm.define "centos8-4" do |i|
    i.vm.box = "eurolinux-vagrant/centos-8"
    i.vm.hostname = "centos8-4"
    i.vm.box_version = "8.4.5"
  end

  config.vm.define "centos8-5" do |i|
    i.vm.box = "eurolinux-vagrant/centos-8"
    i.vm.hostname = "centos8-5"
    i.vm.box_version = "8.5.3"
  end

  config.vm.define "oracle7" do |i|
    i.vm.box = "eurolinux-vagrant/oracle-linux-7"
    i.vm.hostname = "oracle7"
  end

  config.vm.define "oracle8-5" do |i|
    i.vm.box = "eurolinux-vagrant/oracle-linux-8"
    i.vm.hostname = "oracle8-5"
    i.vm.box_version = "8.5.11"
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

  config.vm.define "rhel8" do |i|
    i.vm.box = "rhel8"
    i.vm.box_download_insecure = true
    i.vm.box_url = ENV['VAGRANT_BOX_RHEL8_URL']
    i.vm.hostname = "rhel8"
  end

  config.vm.define "rhel9" do |i|
    i.vm.box = "rhel9"
    i.vm.box_download_insecure = true
    i.vm.box_url = ENV['VAGRANT_BOX_RHEL9_URL']
    i.vm.hostname = "rhel9"
  end

  config.vm.define "generic-rhel7" do |i|
    i.vm.box = "generic/rhel7"
    i.vm.hostname = "generic-rhel7"
    i.vm.hostname = "rhel7"
  end

  config.vm.define "generic-rhel8" do |i|
    i.vm.box = "generic/rhel8"
    i.vm.hostname = "generic-rhel8"
  end

  config.vm.define "rockylinux8-4" do |i|
    i.vm.box = "eurolinux-vagrant/rocky-8"
    i.vm.hostname = "rockylinux8-4"
    i.vm.box_version = "8.4.6"
  end

  config.vm.define "rockylinux8-5" do |i|
    i.vm.box = "eurolinux-vagrant/rocky-8"
    i.vm.hostname = "rockylinux8-5"
    i.vm.box_version = "8.5.11"
  end

  config.vm.define "rockylinux8" do |i|
    i.vm.box = "eurolinux-vagrant/rocky-8"
    i.vm.hostname = "rockylinux8"
  end

  config.vm.define "scientific7" do |i|
    i.vm.box = "eurolinux-vagrant/scientific-linux-7"
    i.vm.hostname = "scientific7"
  end

end
