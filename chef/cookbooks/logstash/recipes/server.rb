include_recipe "logstash::default"

logstash_version = '1.5.3-1'
# Install Logstash 1.5.x
yum_package 'logstash' do
    version logstash_version
    action :install
    notifies :run, 'ruby_block[Add gem thrift to /opt/logstash/Gemfile]', :immediately
end
# In Logstash 1.5, we need to append the names of custom gems that we want, to
# the Gemfile. They'll get installed when Logstash starts up, if needed.
ruby_block "Add gem thrift to /opt/logstash/Gemfile" do
  block do
    file = Chef::Util::FileEdit.new("/opt/logstash/Gemfile")
    file.insert_line_if_no_match(/^gem "thrift"/, 'gem "thrift"')
    file.insert_line_if_no_match(/^gem "finagle-thrift"/, 'gem "finagle-thrift"')
    file.write_file
  end
  action :nothing
end

remote_directory "/etc/logstash/conf.d/" do
    source 'patterns'
    owner 'root'
    group 'root'
    mode '0755'
    files_owner 'logstash'
    files_group 'logstash'
    files_mode '0644'
end

elk_cluster = 'elk'

conf_template = 'logstash.conf.base.erb'
template "/etc/logstash/logstash.conf" do
  source conf_template
  owner "logstash"
  group "logstash"
  mode "0640"
  variables({
    :elk_cluster => elk_cluster
  })
end

if node.get_init_type == 'systemd'
    template "/etc/sysconfig/logstash" do
        source "logstash_sysconfig.erb"
        owner "root"
        group "root"
        mode "0644"
    end

    template "/etc/systemd/system/logstash_server.service" do
        source "logstash_server.service.erb"
        owner "root"
        group "root"
        mode "0644"
        if node.roles.include?("LogstashES")
            variables({ "has_es" => true })
        end
    end

    service "logstash_server" do
        action :enable
    end
else
    template "/etc/init/logstash_server.conf" do
        source "logstash_server.conf.init.erb"
        owner "root"
        group "root"
        mode "0644"
        notifies :start, "service[logstash_server]", :immediately
    end

    service "logstash_server" do
        provider Chef::Provider::Service::Upstart
        action [ :enable ]
    end
end
