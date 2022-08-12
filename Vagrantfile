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

  config.vm.define "centos6" do |i|
    i.vm.box = "eurolinux-vagrant/centos-6"
    i.vm.hostname = "centos6"
  end

  config.vm.define "generic-rhel6" do |i|
    i.vm.box = "generic/rhel6"
    i.vm.hostname = "generic-rhel6"
    i.vm.hostname = "rhel6"
  end

  config.vm.define "scientific6" do |i|
    i.vm.box = "eurolinux-vagrant/scientific-linux-6"
    i.vm.hostname = "scientific6"
  end

end
