# Logstash (since 1.5) has a mature plugin architecture (and tooling) now.
# Install plugins that are defined in the node[:logstash][:additional_plugins]
# hash found in the node's role.
# NOTE: All plugins are Ruby gems and are located at
# /opt/logstash/vendor/bundle/jruby/1.9/gems/.

# NOTE: If the node[:logstash][:additional_plugins] hash is defined for a role,
# the keys should be the names of the desired plugins and their values should be
# the version we want to pin.
# At some point, it may make sense to declare names for logstash clusters such
# that we can create a data bag to store this information rather than doing so
# in the role files.
logstash_root = node[:logstash][:server][:base_dir]
if node[:logstash].has_key? :additional_plugins
  node[:logstash][:additional_plugins].each do |plugin, version|
    execute "Install additional Logstash plugin '#{plugin}-#{version}'" do
      command "#{logstash_root}/bin/plugin install --version #{version} #{plugin}"
      environment ({'JAVA_HOME' => node['logstash']['java_home'] })
      not_if "#{logstash_root}/bin/plugin list --verbose | grep #{plugin} | grep #{version}"
    end
  end
end

