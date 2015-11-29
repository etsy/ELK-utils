case node[:platform_version]
when /^5/
    default[:httpd][:version] = '2.2.3-82.el5.centos'
when /^6/
    default[:httpd][:version] = "2.4.6-18.el6"
when /^7/
    default[:httpd][:version] = "2.4.6-19.el7.centos"
end
