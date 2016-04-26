# -*- mode: ruby -*-

dir = File.dirname(File.expand_path(__FILE__))

require 'yaml'
require "#{dir}/puphpet/ruby/deep_merge.rb"
require "#{dir}/puphpet/ruby/to_bool.rb"
require "#{dir}/puphpet/ruby/puppet.rb"

configValues = YAML.load_file("#{dir}/puphpet/config.yaml")

#print ENV['VAGRANT_DEFAULT_PROVIDER']

target = ENV['VAGRANT_DEFAULT_PROVIDER'] ? ENV['VAGRANT_DEFAULT_PROVIDER'] : 'local'

if File.file?("#{dir}/puphpet/config-#{target}.yaml")
  custom = YAML.load_file("#{dir}/puphpet/config-#{target}.yaml")
  configValues.deep_merge!(custom)
end

if File.file?("#{dir}/puphpet/config-custom.yaml")
  custom = YAML.load_file("#{dir}/puphpet/config-custom.yaml")
  configValues.deep_merge!(custom)
end

data = configValues['vagrantfile']

#print "file:  #{dir}/puphpet/vagrant/Vagrantfile-#{data['target']}"

Vagrant.require_version '>= 1.8.1'

Vagrant.configure('2') do |config|
  eval File.read("#{dir}/puphpet/vagrant/Vagrantfile-#{data['target']}")
end
