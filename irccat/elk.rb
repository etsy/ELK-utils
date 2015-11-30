#!/usr/bin/env ruby

# elk.rb
# Query a ELK's Elasticsearch for information.

require 'net/http'
require 'uri'
require 'json'
require 'resolv'
require 'date'
require 'cgi'

elk_port = "9200"
es_port = "8200"
elasticsearch_name = "elasticsearchmaster.example.com"
elasticsearch_uri = ""
master_cname = ""

def getCNAME(host)
  Resolv::DNS.open do |dns|
    cname = dns.getresources host, Resolv::DNS::Resource::IN::CNAME
    if !cname.empty?
      cname.map { |c|
        printf("#TEAL%-32s#NORMAL%-6s #PINKIN %-7s#NORMAL #CYAN%-32s#NORMAL\n", host, c.ttl, 'CNAME', c.name)
      }
    end
  end
end

def get_master(master_cname)
  getCNAME(master_cname)
  response = get_request("/_cat/nodes?h=master,host,name")
  current_master = ""
  eligible_masters = []
  response.body.split("\n").each do |line|
    (is_master, hostname, nodename) = line.split()
    if is_master.eql?('*')
      current_master = is_es() ? hostname + " " + nodename.partition('-').last : hostname
    elsif is_master.eql?('m')
      eligible_masters << hostname
    end
  end

  printf("#UNDERLINE%-8s|%-10s|%-28s#NORMAL\n", " MASTER ", " ELIGIBLE ", " HOST")
  printf("#GREEN%-8s#NORMAL|%-10s|#GREEN%-28s#NORMAL\n", "   *", "", " #{current_master}")
  eligible_masters = eligible_masters.uniq
  eligible_masters.sort!
  eligible_masters.each do |eligible_master|
    printf("%-8s|#TEAL%-10s#NORMAL|#TEAL%-28s#NORMAL\n", "", "    *", " #{eligible_master}")
  end
end

def get_indices(index_prefix = nil, index_count = nil)
  health_colors = {
    'green'     => 'GREEN',
    'yellow'    => 'YELLOW',
    'red'       => 'RED',
  }
  indices_response = get_request("/_cat/indices")
  # Build up a hash of AoHs that comprise index info. The keys are the index prefix.
  # Ex. The index prefix for 'logstash-2015.01.27' is 'logstash'.
  # We can then sort by hash key, then sort by their hash;s 'index_name' to display the 2
  # most recent indices for a given prefix. Tidy like.
  #
  # index_info = {
  #   logstash = [
  #     {index_name' => 'logstash-2015.01.26', 'index_health' => 'green', 'index_size' => '2.7tb', ...},
  #     {index_name' => 'logstash-2015.01.27', 'index_health' => 'green', 'index_size' => '2.9tb', ...},
  #     ...
  #   ]
  # }
  #
  # We'll build up the AoAs so that each nested array's first value is the index
  # named that (typically) contains a date component.
  index_info = {}
  indices_response.body.split("\n").each do |line|
    (index_health, index_status, index_name, pri_shard_count, rep_shard_multiplier, doc_count, doc_deleted_count, store_size, pri_store_size) = line.split()
    replica_shard_count = (pri_shard_count.to_i * rep_shard_multiplier.to_i).to_s
    # Ignore the 'trash' indices; they're not that interesting in most/all cases we care about.
    next if index_name =~ /-trash$/
    index_key = is_es() ? index_name.gsub(/-[0-9]*/, '') : index_name.gsub(/-\d{4}\.\d{2}\.\d{2}/, '')
    index_info[index_key] = [] unless index_info.has_key?(index_key)
    index_info[index_key] << {'index_name' => index_name, 'index_health' => index_health, 'store_size' => store_size, 'pri_store_size' => pri_store_size, 'pri_shard_count' => pri_shard_count, 'replica_shard_count' => replica_shard_count}
  end
  # If we've not been given an index prefix, enumerate the index prefixes.
  if index_prefix.nil?
    printf("#UNDERLINE%-20s|%7s#NORMAL\n", " INDEX PREFIX ", " COUNT ")
    index_info.keys.sort.each do |index_prefix|
      printf("%-20s|%7s\n", " #{index_prefix} ", " #{index_info[index_prefix].length} ")
    end
  else
    # Display info about indices for the given index prefix.
    # List the index_count most recent indices, based on index name.
    # Default to 2.
    if index_count.nil?
      most_recent_indices = index_info[index_prefix].sort_by{|index| index['index_name']}.reverse.take(2)
    else
      most_recent_indices = index_info[index_prefix].sort_by{|index| index['index_name']}.reverse.take(index_count.to_i)
    end
    printf("#UNDERLINE%-24s|%-8s|%9s|%10s|%9s|%9s#NORMAL\n", " INDEX ", " HEALTH ", " SIZE ", " PRI SIZE ", " P SHARD ", " R SHARD ")
    most_recent_indices.each do |index|
      printf("%-24s|##{health_colors[index['index_health']]}%-8s#NORMAL|%9s|%10s|%9s|%9s\n", index['index_name'], " #{index['index_health']} ", " #{index['store_size']} ", " #{index['pri_store_size']} ", " #{index['pri_shard_count']} ", " #{index['replica_shard_count']} ")
    end
  end
end

def get_nodes
  response = get_request("/_cat/nodes?h=master,node.role,name")
  client_nodes = []
  data_nodes = []
  eligible_masters = []
  response.body.split("\n").each do |line|
    (is_master, noderole, nodename) = line.split()
    if is_master.eql?('*') or is_master.eql?('m')
      eligible_masters << nodename
    end
    if noderole.eql?('d') and is_master.eql?('-')
      data_nodes << nodename
    end
    if noderole.eql?('-') and is_master.eql?('-')
      client_nodes << nodename
    end
  end
  printf("#UNDERLINE%-8s|%-8s#NORMAL\n", " TYPE ", " COUNT ")
  printf("%-8s|%8s\n", " CLIENT ", "#{client_nodes.length}")
  printf("%-8s|%8s\n", " DATA ", "#{data_nodes.length}")
  printf("#UNDERLINE%-8s|%8s#NORMAL\n", " MASTER ", "#{eligible_masters.length}")
  printf("#TEAL%-8s#NORMAL|#TEAL%8s#NORMAL\n", " TOTAL ", "#{client_nodes.length + data_nodes.length + eligible_masters.length}")
end

def get_node_info(node_name)
   response = get_request("/_cat/shards\?v")
   started_indices = 0
   init_indices = 0
   relo_indices = 0
   response.body.each_line do |line|
       if line.include?(node_name)
           if line.include?("STARTED")
               started_indices += 1
           elsif line.include?("RELO")
               relo_indices += 1
           elsif line.include?("INIT")
               init_indices += 1
           end
       end
    end
    response = get_request("/_cat/nodes\?v")
    node_role_code = "-"
    response.body.each_line do |line|
        if line.include?(node_name)
            node_role_code = line.split(" ")[5]
        end
    end
    if node_role_code == "d"
        node_role = "data node"
    elsif node_role_code == "c"
        node_role = "client node"
    else
        node_role = "unknown"
    end
    puts("Node #TEAL#{node_name}#NORMAL (with role #TEAL#{node_role}#NORMAL) has:")
    puts("#{started_indices} started indices")
    puts("#{init_indices} initializing indices")
    puts("#{relo_indices} relocating indices")
end

# Get information on the state of all shards.
# Optionally, return information for a specific shard type, because code reuse.
# Shard types:
#  STARTED      - The shard is online and available.
#  INITIALIZING - The shard is being brought online.
#  RELOCATING   - The shard is being migrated to another ES node.
#  UNASSIGNED   - The shard is offline and waiting to be initialized.
def get_shards(shard_type = nil)
  response = get_request("/_cat/shards?h=prirep,state")
  primary_started = 0
  primary_initializing = 0
  primary_relocating = 0
  primary_unassigned = 0
  replica_started = 0
  replica_initializing = 0
  replica_relocating = 0
  replica_unassigned = 0
  response.body.split("\n").each do |line|
    (prirep, state) = line.split()
    if prirep.eql?('p')
      primary_started += 1 if state =~ /STARTED/
      primary_initializing += 1 if state =~ /INITIALIZING/
      primary_relocating += 1 if state =~ /RELOCATING/
      primary_unassigned += 1 if state =~ /UNASSIGNED/
    elsif prirep.eql?('r')
      replica_started += 1 if state =~ /STARTED/
      replica_initializing += 1 if state =~ /INITIALIZING/
      replica_relocating += 1 if state =~ /RELOCATING/
      replica_unassigned += 1 if state =~ /UNASSIGNED/
    end
  end

  case shard_type
  when "started"
    return [primary_started, replica_started]
  when "intializing"
    return [primary_intializing, replica_intializing]
  when "relocating"
    return [primary_relocating, replica_relocating]
  when "unassigned"
    return [primary_unassigned, replica_unassigned]
  else
    # GIMME ALL YA GOT!
    printf("#UNDERLINE%-8s|%-14s|%-8s#NORMAL\n", "TYPE", "STATUS", "COUNT")
    printf("#BLUE%-8s#NORMAL|#GREEN%-14s#NORMAL|%8d\n", "PRIMARY", " STARTED", primary_started)
    printf("%-8s|#RED%-14s#NORMAL|%8d\n", "   -", " INITIALIZING", primary_initializing)
    printf("%-8s|#RED%-14s#NORMAL|%8d\n", "   -", " RELOCATING", primary_relocating)
    printf("%-8s|#RED%-14s#NORMAL|%8d\n", "   -", " UNASSIGNED", primary_unassigned)
    printf("#UNDERLINE%-8s|%-14s|%8d#NORMAL\n", "", " TOTAL", primary_started + primary_initializing + primary_relocating + primary_unassigned)
    printf("#TEAL%-8s#NORMAL|#GREEN%-14s#NORMAL|%8d\n", "REPLICA", " STARTED", replica_started)
    printf("%-8s|#RED%-14s#NORMAL|%8d\n", "   -", " INITIALIZING", replica_initializing)
    printf("%-8s|#RED%-14s#NORMAL|%8d\n", "   -", " RELOCATING", replica_relocating)
    printf("%-8s|#RED%-14s#NORMAL|%8d\n", "   -", " UNASSIGNED", replica_unassigned)
    printf("#UNDERLINE%-8s|%-14s|%8d#NORMAL\n", "", " TOTAL", replica_started + replica_initializing + replica_relocating + replica_unassigned)
  end

end

# Tell the operator if the cluster has shard rebalancing enabled.
# (persistent|transient).cluster.routing.allocation.cluster_concurrent_rebalance
def get_rebalance_info(node=nil)
  cluster_settings = get_cluster_settings
  # Go deep, looking for the 'cluster_concurrent_rebalance' value.
  # We expect it under the 'persistent' key always.
  persistent_cluster_rebalance = cluster_settings['persistent'].fetch('cluster',{}).fetch('routing',{}).fetch('allocation',{}).fetch('cluster_concurrent_rebalance',nil)
  # Check the 'transient' key as well, just in case.
  transient_cluster_rebalance = cluster_settings['transient'].fetch('cluster',{}).fetch('routing',{}).fetch('allocation',{}).fetch('cluster_concurrent_rebalance',nil)

  # Count the number of relocating shards. We can have some in-flight even
  # if rebalancing has been disabled.
  (relocating_primaries, relocating_replicas) = get_shards('relocating')
  printf("#UNDERLINE%-14s|%-19s|%-16s|%-16s#NORMAL\n", " RE-BALANCING ", " CONCURRENT SHARDS ", " RELOCATING PRI ", " RELOCATING REP ")
  # I believe transient settings take precendence, especially as they
  # don't survive cluster restarts.
  if transient_cluster_rebalance and transient_cluster_rebalance.to_i > 0
    printf("#GREEN%-14s#NORMAL|%19s|%16s|%16s\n", " ON ", " #{transient_cluster_rebalance} ", " #{relocating_primaries} ", " #{relocating_replicas} ")
  elsif persistent_cluster_rebalance and persistent_cluster_rebalance.to_i > 0
    printf("#GREEN%-14s#NORMAL|%19s|%16s|%16s\n", " ON ", " #{persistent_cluster_rebalance} ", " #{relocating_primaries} ", " #{relocating_replicas} ")
  else
    printf("#RED%-14s#NORMAL|%19s|%16s|%16s\n", " OFF ", " 0 ", " #{relocating_primaries} ", " #{relocating_replicas} ")
  end

  if node
    # If a specific node name is passed in, show any ongoing recoveries to or from that node
    rebalancing_shards = @http.get("/_cat/recovery?active_only=true&v").body
    response_lines = rebalancing_shards.split("\n")
    rebalancing_nodes = response_lines[1..-1]
    rebalancing_nodes.each do |line|
      if line.include? node
        puts "INDEX: #{line.split[0]} TYPE: #{line.split[3]} FROM: #{line.split[5]} TO: #{line.split[6]} FILES %: #{line.split[10]} BYTES %: #{line.split[12]}"
      end
    end  
  end
end

# Print ES snapshot repos
def get_repos
  repo_response = get_request("/_snapshot").body
  repo_info = JSON.parse(repo_response)
  printf("#UNDERLINE%-12s|%-10s|%13s|%14s|%-30s#NORMAL\n", " REPO ", " COMPRESS ", " BACKUP RATE ", " RESTORE RATE ", " LOCATION ")
  repo_info.each_key do |repo_name|
    if repo_info[repo_name]['settings']['location'].nil?
      repo_location = '-'
    else
      repo_location = repo_info[repo_name]['settings']['location']
    end
    if repo_info[repo_name]['settings']['compress'].nil?
      repo_compression = '-'
    else
      repo_compression = repo_info[repo_name]['settings']['compress']
    end
    if repo_info[repo_name]['settings']['max_snapshot_bytes_per_sec'].nil?
      snapshot_backup_rate = '-'
    else
      snapshot_backup_rate = repo_info[repo_name]['settings']['max_snapshot_bytes_per_sec']
    end
    if repo_info[repo_name]['settings']['max_restore_bytes_per_sec'].nil?
      snapshot_restore_rate = '-'
    else
      snapshot_restore_rate = repo_info[repo_name]['settings']['max_restore_bytes_per_sec']
    end
    printf("%-12s|%10s|%13s|%14s|%30s\n", repo_name, "#{repo_compression} ", "#{snapshot_backup_rate} ", "#{snapshot_restore_rate} ", repo_location)
  end
end

# Enumerate ES snapshots, per repo.
def get_snapshots
  state_colors = {
    'SUCCESS'       => 'GREEN',
    'PARTIAL'       => 'RED',
    'IN_PROGRESS'   => 'YELLOW',
  }
  repo_response = get_request("/_snapshot").body
  repo_info = JSON.parse(repo_response)
  # Print information about the most recent n snaphots, per repo.
  printf("#UNDERLINE%-12s|%-24s|%-13s|%-21s|%-21s|%-17s#NORMAL\n", " REPO ", " SNAPSHOT NAME ", " STATE ", " START ", " END ", " DURATION ")
  cluster = ARGV[1]
  bundle = ARGV[2]

  repo_info.each_key do |repo_name|
    next if is_es() and repo_name != cluster + "-" + bundle
    snapshot_response = get_request("/_snapshot/#{repo_name}/_all").body
    snapshot_info = JSON.parse(snapshot_response)

    if snapshot_info['snapshots'].empty?
        printf("%-15s|%-32s|%-13s|%-26s|%-26s\n", repo_name, " - ", " - ", " - ", " - ")
    else
      # Temporarily store all snapshot results for later sorting.
      # Snapshot details are keyed by the epoch of their start date.
      all_snapshots = {}
      snapshot_info['snapshots'].each do |snapshot|
        # Snapshot start.
        snapshot_start_datetime = DateTime.iso8601(snapshot['start_time'])
        snapshot_start_epoch = snapshot_start_datetime.to_time.to_i
        snapshot_start_timestamp = snapshot_start_datetime.strftime('%Y-%m-%d %H:%M:%S')
        # Snapshot end.
        if snapshot['end_time'].nil?
          snapshot_end_epoch = 0
          snapshot_end_timestamp = '-'
        else
          snapshot_end_datetime = DateTime.iso8601(snapshot['end_time'])
          snapshot_end_epoch = snapshot_end_datetime.to_time.to_i
          snapshot_end_timestamp = snapshot_end_datetime.strftime('%Y-%m-%d %H:%M:%S')
        end
        if snapshot_end_epoch <= 0
          snapshot_duration = '-'
        else
          # Contrived, but working, method to get time duration.
          snapshot_timediff = snapshot_end_epoch - snapshot_start_epoch
          min, sec = snapshot_timediff.divmod(60)
          hours, min = min.divmod(60)
          days, hours = hours.divmod(24)
          snapshot_duration = sprintf("%dd %dh %dm %ds", days, hours, min, sec)
        end
        all_snapshots[snapshot_start_epoch] = {'state' => snapshot['state'], 'snapshot_name' => snapshot['snapshot'], 'start_time' => snapshot_start_timestamp, 'end_time' => snapshot_end_timestamp, 'duration' => snapshot_duration }
      end
      # Sort (by keys, default) and get first 3 items returned in the AoA.
      most_recent_snaps = all_snapshots.sort.reverse.take(3)

      most_recent_snaps.each do |snap| 
        snap_start_epoch = snap[0]
        snap_details = snap[1]
        printf("%-12s|%-24s|##{state_colors[snap_details['state']]}%-13s#NORMAL|%-21s|%-21s|%-17s\n", repo_name, " #{snap_details['snapshot_name']} ", " #{snap_details['state']} ", " #{snap_details['start_time']} ", " #{snap_details['end_time']} ", " #{snap_details['duration']} ")
      end
    end
  end
end

def get_cluster_health
  response = get_request("/_cluster/health")
  return JSON.parse(response.body)
end

def get_cluster_settings
  response = get_request("/_cluster/settings")
  return JSON.parse(response.body)
end

@all_settings = []

# Like a depth-first search.
def enumerate_hash(root, key, value)
  if root.empty?
    current_root = key
  else
    current_root = "#{root}.#{key}"
  end
  #puts current_root
  if value.is_a?(String)
    @all_settings << "#{current_root} = #{value}"
  elsif value.is_a?(Hash)
    value.each do |k,v|
      enumerate_hash(current_root, k, v)
    end
  elsif value.is_a?(Array)
    # I'm making a very naive assumption that arrays will not contain
    # items who are anything other than strings. This will bite me in the rear
    # later. For now, I want to get this out knowing that the namespace
    # isn't that complex at the moment.
    @all_settings << "#{current_root} = #{value.join(', ')}"
  end
end

def enumerate_cluster_settings
  settings_json = get_cluster_settings
  ['persistent', 'transient'].each do |settings_key|
    if settings_json.has_key? settings_key
      settings_json[settings_key].each do |top_level_key,value|
        enumerate_hash(settings_key, top_level_key, value)
      end
    end
  end
  return @all_settings.sort
end

def set_rebalance_setting(rebalance_amount=nil)
    # Set the rebalancing factor on the cluster. But also check that the input makes sense.
    if not rebalance_amount
        printf("Usage: ?elk rebalancing <num>\n")
        printf("0 will disable rebalancing, 8 is highest amount of rebalancing we can safely do.")
        return
    elsif rebalance_amount.to_i > 8 or rebalance_amount.to_i < 0
        printf("Rebalancing factor must be between 0 and 8. 0 will disable rebalancing, 8 is highest amount of rebalancing we can safely do.")
        return
    else
        settings_json = {"persistent" => {"cluster.routing.allocation.cluster_concurrent_rebalance" => "#{rebalance_amount}"} }.to_json
        response = @http.put("/_cluster/settings", settings_json)
        printf("#{response.body} (#{response.code} #{response.message})")
    end
end

def set_recovery_setting(recovery_max_bytes=nil)
    # Set the recovery.max_bytes_per_sec on the cluster. Also make sure input is sensible.
    if not recovery_max_bytes
        printf("Usage: ?elk maxbytes <number of mb>\n")
        return
    elsif recovery_max_bytes.to_i <= 0 or recovery_max_bytes.to_i > 500
        printf("Max bytes should be between 1 (very slow) and 500 (very fast). Keep in mind this number is in MB.\n")
        return
    else
        settings_json = {"persistent" => {"indices.recovery.max_bytes_per_sec" => "#{recovery_max_bytes}mb"} }.to_json
        response = @http.put("/_cluster/settings", settings_json)
        printf("#{response.body} (#{response.code} #{response.message})")
    end
end

def get_recovery_info
    response = @http.get("_cat/recovery?active_only=true\&v")
    sorted = response.body.lines.sort_by { |line| line.split(" ")[12].gsub("%", "").to_i }.reverse
    if sorted.size > 11
        puts "#{sorted.size - 1 } recoveries in progress, showing 10 farthest along:"
    else
        puts "#{sorted.size - 1 } recoveries in progress:"
    end
    header = sorted.pop
    h = header.split(" ")
    puts "#{h[0]} #{h[3]} #{h[4]} #{h[5]} #{h[6]} #{h[10]} #{h[12]}"
    sorted.take(10).each do |line|
        l = line.split(" ")
        puts "#{l[0]} #{l[3]} #{l[4]} #{l[5]} #{l[6]} #{l[10]} #{l[12]}"
    end
end

def is_es()
    if $0 =~ /es/
        return true
    end
    return false
end

if ARGV.length == 0
    puts "Whatchoo want? elk.md for ideas"
    exit
end

elasticsearch_uri = "http://" + elasticsearch_name + ":" + elk_port
master_cname = elasticsearch_name

uri = URI.parse(elasticsearch_uri)
@http = Net::HTTP.new(uri.host, uri.port)

case ARGV[0]
when 'health', 'status'
    health = get_cluster_health
    status = health['status']
    cluster_name = health['cluster_name'] 
    puts "Elasticsearch cluster, #{cluster_name}, health is #BOLD##{status.upcase}#{status.upcase}#NORMAL"
when 'help'
    puts "See elk.md"
when 'indices'
    index_prefix = is_es() ? ARGV[3] : ARGV[1]
    index_count = is_es() ? ARGV[4] : ARGV[2]
    if index_prefix != nil and index_count != nil
        get_indices(index_prefix, index_count)
    elsif index_prefix != nil
        get_indices(index_prefix)
    else
        get_indices
    end
when 'master'
    get_master(master_cname)
when /^node/
    if ARGV[1]
        get_node_info(ARGV[1])
    else
        get_nodes
    end
when /rebalancing/
    get_rebalance_info(ARGV[1])
when /^repo/
    get_repos
when /^shard/
    get_shards
when 'settings'
    cluster_settings = enumerate_cluster_settings
    gist_url = `echo -e ">> Elasticsearch Cluster Settings << \n\n#{cluster_settings.join("\n")}"`
    puts gist_url
when /^snapshot/
    get_snapshots
when 'setrebalancing'
    rebalance_amount = is_es() ? ARGV[3] : ARGV[1]
    set_rebalance_setting(rebalance_amount)
when 'maxbytes'
    recovery_max_bytes = is_es() ? ARGV[3] :  ARGV[1]
    set_recovery_setting(recovery_max_bytes)
when 'recovery'
    get_recovery_info
else
    puts "Unknown argument! See elk.md for help"
end





