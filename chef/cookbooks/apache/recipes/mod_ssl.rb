package "mod_ssl" do
    action :install
    version node[:httpd][:version]
end
