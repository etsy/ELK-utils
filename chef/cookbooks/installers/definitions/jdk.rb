#
# This definition provides a modular way of installing multiple JDKs
# from tarballs hosted on a file server
#

define :jdk, :filename =>'', :default => false, :links => [] do

  directory "/usr/java" do
    action :create
  end

  remote_file "/opt/#{params[:filename]}" do
    source "http://fileserver.example.com/chef/jdk/#{params[:filename]}"
    not_if {File.exists?("/usr/java/#{params[:name]}")}
    owner "root"
    group "root"
    mode 00600
  end

  bash "install_jdk_#{params[:name]}" do
    only_if {File.exists?("/opt/#{params[:filename]}")}
    not_if {File.exists?("/usr/java/#{params[:name]}")}
    code <<-CMD
    cd /usr/java
    /bin/tar -zxf /opt/#{params[:filename]}
    rm /opt/#{params[:filename]}
    CMD
  end

  params[:links].each do |l|
    link l do
      to "/usr/java/#{params[:name]}"
    end
  end

  if params[:default]
    link "/usr/java/default" do
      to "/usr/java/#{params[:name]}"
    end
  end

  execute "fix #{params[:name]} perms" do
    command "chown -R root: /usr/java/#{params[:name]}"
    not_if {File.stat("/usr/java/#{params[:name]}").uid == 0}
  end

end
