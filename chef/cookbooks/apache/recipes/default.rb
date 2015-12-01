#
# Cookbook Name:: apache
# Recipe:: default
#
# Copyright 2010, Example Com
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

yum_package "httpd" do
  action :install
  version node[:httpd][:version]
  allow_downgrade true
end

include_recipe "logrotate::httpd"

# Set the 'apache' user's homedir to /var/www. We typically handle this in
# the RPM spec, but this is a handy guard, just in case.
# NOTE: This is mostly for first Chef runs on new builds as the user cannot
# be modified if a process is currently running in the user's context.
user "apache" do
  action :modify
  home "/var/www"
end

# for apache on cent6, force an install of the appropriate apr packages
if node[:platform_version].start_with?('6')
  package "apr" do
    action :install
    version '1.4.2-1'
  end

  package "apr-util" do
    action :install
    version '1.4.1-1'
  end
end

template_variables = {
  :fqdn => node[:fqdn],
  :port => "80",

  # prefork mpm settings
  :start_servers => 30,
  :min_spare_servers => 30,
  :max_spare_servers => 60,
  :server_limit => 80,
  :max_clients => 80,
  :max_requests_per_child => 0,

  # Keepalive settings
  :keepalive => false,
  :keepalive_timeout => 2,
  :keepalive_max_requests => 100,

  # Timeouts
  :timeout => 60
}

template "/etc/httpd/conf/httpd.conf" do
  source "httpd-conf.erb"
  owner "root"
  group "root"
  mode 00644
  variables(template_variables)
end

service "httpd" do
  action [:enable]
end

cookbook_file "/etc/init.d/httpd" do
  source "httpd.initd"
  owner "root"
  group "root"
  mode 00755
end


