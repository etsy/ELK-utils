default[:logstash][:server][:es_server] = "localhost"
default[:logstash][:server][:es_workers] = node[:habitat] == "production" ? node[:cpu][:total]/2 : 1
default[:logstash][:flush_size] = node[:habitat] == "production" ? 10000 : 500
default[:logstash][:server][:base_dir] = "/opt/logstash"

inputs = [
  {
    :lumberjack => {
      :codec => 'plain',
      :port => 9991
    }
  }
]

inputs.concat([
  {
    :udp => {
      :port => 8211,
      :codec => "json"
    }
  },
  {
    :udp => {
      :port => 8212,
      :codec => "msgpack"
    }
  },
  {
    :tcp => {
      :port => 8213,
      :codec => "json_lines"
    }
  },
  {
    :syslog => {
      :type => "syslog"
    }
  },
  {
    :heartbeat => {
      :message => "epoch",
      :type => "heartbeat"
    }
  }
])
default[:logstash][:server][:gc_opts] = "-XX:NewRatio=3 -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -XX:+PrintTenuringDistribution -Xloggc:/var/log/logstash/gc.log -XX:+PrintGC"
default[:logstash][:server][:ls_mem] = "31G"
default[:logstash][:server][:worker_limit] = (node[:cpu][:total]).to_int * 2
default[:logstash][:server][:es_cluster] = "elasticsearch"
end

default[:logstash][:server][:inputs] = inputs
