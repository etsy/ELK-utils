#
# Cookbook Name:: kibana
# Recipe:: default
#
# Copyright 2013, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

kibana_path = "/opt/kibana"

user "kibana" do
  action :create
  group "kibana"
end

directory kibana_path do
  owner "kibana"
  group "kibana"
  mode 0775
  recursive true
  action :create
end

git kibana_path do
  only_if {File.exists?(kibana_path) and File.stat(kibana_path).nlink == 2}
  repository "https://github.com/elastic/kibana"
  reference "master"
  action :checkout
  user "kibana"
  group "kibana"
end

template "/etc/httpd/conf.d/logs.example.com.conf" do
  source "logs.example.com.conf.erb"
  owner "root"
  group "root"
  mode 00755
  variables({
    :hostname => node[:kibana][:vhost][:server_name],
    :aliases => node[:kibana][:vhost][:server_aliases],
    :require_auth => node[:kibana][:vhost][:require_auth],
    :log_prefix => "kibana",
    :docroot => "#{kibana_path}/src"
  })
  notifies :reload, "service[httpd]", :immediately
end

default_dashboard = "logstash"

