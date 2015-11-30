# Per-node and cluster configurations are now managed by the
# elasticsearch/config data bag. Please make required changes there

instances = (1..node[:elasticsearch][:num_instances]).to_a
es_version = "1.5.2-1"

# Install Elasticsearch
package "elasticsearch" do
    version es_version
    action :install
end

# Create ES directories
node[:elasticsearch][:data_path].split(',').each do |path|
    directory path do
        owner "elasticsearch"
        group "elasticsearch"
        mode 0755
        recursive true
        action :create
    end
end

if node[:platform_version].to_f < 7.0
  directory '/var/run/elasticsearch' do
    owner 'elasticsearch'
    group 'elasticsearch'
    mode '0755'
    action :create
  end
end

instances.each do |inst|
  case node[:platform_version]
  when /^7/
    template "/etc/systemd/system/elasticsearch#{inst}.service" do
        source "elasticsearch.service.erb"
        owner "root"
        group "root"
        mode 00755
        variables({ 'instance' => inst })
    end
  else
    template "/etc/init.d/elasticsearch#{inst}" do
        source "elasticsearch.init.erb"
        owner "root"
        group "root"
        mode 00755
        variables({ 'instance' => inst })
    end
  end
  service "elasticsearch#{inst}" do
    action [ :enable ]
  end

  template "/etc/sysconfig/elasticsearch#{inst}" do
    source "nodedata_elasticsearch.sysconfig"
    owner "root"
    group "root"
    mode 00444
    variables({ 'java_home' => node[:elasticsearch][:java_home],
                'instance' => inst })
  end
  file "/etc/sysconfig/elasticsearch" do
    action :delete
  end
 
  # Kibana instances are tribe nodes, which connect to multiple clusters.
  # They need a specific config.
  if node[:hostname] =~ /\bkibana[0-9]{2}\b/
      cfg_tpl = "kibanatribe_elasticsearch.yml.erb"
  else
      cfg_tpl = "nodedata_elasticsearch.yml.erb"
  end

  # Create ES config file
  template "#{node[:elasticsearch][:conf_dir]}/elasticsearch#{inst}.yml" do
    source cfg_tpl
    owner "elasticsearch"
    group "elasticsearch"
    mode 0444
    variables({ 'instance' => inst,
              'es_version' => es_version })
  end
  file "/etc/elasticsearch/elasticsearch.yml" do
    action :delete
  end
  directory "/var/log/elasticsearch#{inst}" do
    action :create
    owner "elasticsearch"
    group "elasticsearch"
    mode 0755
  end
end

# For Cent 6 we'll use a wrapper init script for all ES init scripts.
case node[:platform_version]
when /^6/
  cookbook_file "/etc/init.d/elasticsearch" do
      source "elasticsearch.rc"
      owner "root"
      group "root"
      mode 00755
  end
when /^7/
  # Disable the stock elasticsearch service that's provided by the Cent7 package.
  service "elasticsearch" do
    action [ :disable ]
  end
end

if node[:elasticsearch][:is_master]
  # Store elasticsearch templates
  directory "#{node[:elasticsearch][:conf_dir]}/templates" do
    owner "elasticsearch"
    group "elasticsearch"
    action :create
  end

  node[:elasticsearch][:index_templates].each do |template_type|
    template "#{node[:elasticsearch][:conf_dir]}/templates/#{template_type}-template.json" do
      source "es_templates/#{template_type}-template.json.erb"
      owner "elasticsearch"
      group "elasticsearch"
      mode 00644
      notifies :run, "execute[import-#{template_type}-template]"
    end

    execute "import-#{template_type}-template" do
      command "curl -XDELETE http://localhost:9200/_template/#{template_type}; curl -XPUT http://localhost:9200/_template/#{template_type} -d @#{node[:elasticsearch][:conf_dir]}/templates/#{template_type}-template.json"
      action :nothing
      only_if "/sbin/service elasticsearch1 status | grep running"
    end
  end
end

# See https://ccp.cloudera.com/display/CDH4DOC/Known+Issues+and+Work+Arounds+in+CDH4#KnownIssuesandWorkAroundsinCDH4-RHELcurrent
# and https://blogs.oracle.com/linux/entry/performance_issues_with_transparent_huge
case node[:platform_version]
when /^7/
    hugepage_enable_file = "/sys/kernel/mm/redhat_transparent_hugepage/enabled"
    hugepage_defrag_file = "/sys/kernel/mm/redhat_transparent_hugepage/defrag"
else
    hugepage_enable_file = "/sys/kernel/mm/transparent_hugepage/enabled"
    hugepage_defrag_file = "/sys/kernel/mm/transparent_hugepage/defrag"
end
execute "disable hugepage defragmentation" do
  command "echo never > #{hugepage_defrag_file}"
  user "root"
  only_if "grep ' never' #{hugepage_defrag_file}"
end
execute "disable hugepage support" do
  command "echo never > #{hugepage_enable_file}"
  user "root"
  only_if "grep ' never' #{hugepage_enable_file}"
end

