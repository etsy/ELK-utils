require 'json'

# This recipe controls logstash-forwarder/lumberjack installation and configuration.
# It works on both Linux and OS X, so please be aware of any OS specific definitions.
# There are many already here, so they're inside if blocks.

# Figure out which servers we need to know about
lj_network = []
lj_network << node.default[:lumberjack][:default_servers]

# All the following stuff needs to happen on Linux, namely CentOS
if node[:platform] != 'mac_os_x'
  lumberjack_version = "0.4.7-1"

  yum_package "lumberjack" do
    action :install
    version lumberjack_version
    flush_cache [:before]
    allow_downgrade true
    notifies :restart, "service[lumberjack]", :delayed
  end

  file "/opt/lumberjack/bin/lumberjack" do
    mode 00755
  end

  case node[:platform_version]
  when /^6/
    lumberjack_init_script = "/etc/init/lumberjack.conf"
    lumberjack_init_src = "lumberjack.init.erb"
    service "lumberjack" do
      action [ :nothing ]
      provider lumberjack_provider = Chef::Provider::Service::Upstart
    end
  when /^7/
    lumberjack_init_script = "/etc/systemd/system/lumberjack.service"
    lumberjack_init_src = "lumberjack.service.erb"
    service "lumberjack" do
      action [ :nothing ]
    end
  end

  file "/etc/init.d/lumberjack" do
    action :delete
  end

  template "#{lumberjack_init_script}" do
    source "#{lumberjack_init_src}"
    owner 'root'
    group 'root'
    mode 00444
    notifies :restart, "service[lumberjack]", :delayed
  end
end # End Linux/CentOS stuff

# Here are the differences between OS X and Linux.
if node[:platform] == 'mac_os_x'
  # On OS X, Lumberjack is formerly known as logstash-forwader
  program_name = 'logstash-forwarder'
  service 'com.elasticsearch.logstash-forwarder' do
    action [ :enable ]
  end
  config_file_owner = "root"
  config_file_group = "staff"

  # On OS X, we can't "restart" services, so we just kill them and launchd
  # brings them back, yay. This is called by the logstash config being changed.
  execute "reload_logstash_forwarder" do
    command "/usr/bin/pkill logstash-forwarder"
    action :nothing
  end

  # Since logstash-forwarder doesn't support multiple desitnations like
  # lumberjack does (yet), and we only send to corpelk, just set the array to that.
  lj_network = node[:lumberjack][:corpelk]

else
  # Logstash-forwarder is still known as lumberjack on Linux, for now.
  program_name = 'lumberjack'
  config_file_owner = "root"
  config_file_group = "root"
end

template "/etc/#{program_name}.conf" do
  source 'lumberjack.conf.erb'
  owner config_file_owner
  group config_file_group
  mode 00444
  variables({
    :network_json => JSON.pretty_generate(lj_network),
    :files_json => JSON.pretty_generate(node[:lumberjack_files])
  })
  case node[:platform]
  when "centos", "redhat"
    notifies :restart, "service[lumberjack]", :delayed
  when "mac_os_x"
    notifies :run, resources(:execute => "reload_logstash_forwarder"), :delayed
  end
end

service "lumberjack" do
  action :start
end

