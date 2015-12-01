# Define some sane defaults and process the elasticsearch/config data bag
#
# The data bag contains definitions for multi-node clusters in the 'clusters'
# key and also allows attribute overrides for any node in the 'nodes' key.

default[:elasticsearch][:cluster_name] = node[:hostname]
default[:elasticsearch][:is_local] = false
default[:elasticsearch][:is_master] = true
default[:elasticsearch][:is_data] = true

default[:elasticsearch][:expected_master_nodes] = 1
default[:elasticsearch][:expected_data_nodes] = 1
default[:elasticsearch][:recover_after_time] = "5m"

default[:elasticsearch][:backup_host] = nil
default[:elasticsearch][:graphite_host] = nil
default[:elasticsearch][:run_snapshots] = false
default[:elasticsearch][:node_name] = node[:fqdn]
default[:elasticsearch][:http_enabled] = true
default[:elasticsearch][:conf_dir] = "/etc/elasticsearch"
default[:elasticsearch][:log_dir] = "/var/log/elasticsearch"
default[:elasticsearch][:es_home] = "/usr/share/elasticsearch"
default[:elasticsearch][:max_thread_count] = 1
default[:elasticsearch][:num_instances] = 1
default[:elasticsearch][:data_path] = "/data/elasticsearch"

base_gc_opts="-XX:+UseParNewGC
         -XX:CMSInitiatingOccupancyFraction=75
         -XX:+CMSScavengeBeforeRemark
         -XX:+UseConcMarkSweepGC
         -XX:+CMSParallelRemarkEnabled
         -XX:+UseCMSInitiatingOccupancyOnly
         -XX:HeapDumpPath=/usr/share/elasticsearch/heapdump.hprof"
default[:elasticsearch][:es_mem] = "31G"
default[:elasticsearch][:jvm_newsize] = "22G"
default[:elasticsearch][:gc_opts] = base_gc_opts + "
           -XX:+PrintGCDetails
           -XX:+PrintGCTimeStamps
           -XX:+PrintClassHistogram
           -XX:+PrintTenuringDistribution
           -XX:+PrintGCApplicationStoppedTime"

