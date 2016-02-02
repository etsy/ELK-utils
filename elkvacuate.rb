#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'
require 'optparse'

options = {}
OptionParser.new do |opts|
    opts.banner = "Usage: elkvacuate.rb -a {evacuate|invacuate} -h host [-s stack]"
    opts.on('-a', '--action A', String, "Action to take on node") { |v| options[:action] = v }
    opts.on('-h', '--host H', String, "Host to evacuate or invacuate") { |v| options[:host] = v }
    opts.on('-u', '--url U', String, "URL of Elasticsearch master") { |v| options[:url] = v }
    opts.on('-p', '--port P', String, "Port the ES master is listening on (default is 9200)") { |v| options[:port] = v }
end.parse! 

if not options[:port]
    options[:port] = "9200"
end
elasticsearch_uri = "#{options[:url]}:#{options[:port]}"
uri = URI.parse(elasticsearch_uri)
@http = Net::HTTP.new(uri.host, uri.port)

def get_settings_node_list(settings_hash, index, type)
    # Gets the include or exclude list from the settings json
    # type must be one of include or exclude
    begin
        list = settings_hash["#{index}"]['settings']['index']['routing']['allocation'][type]['_host']
    rescue Exception => e
        # If one of those keys doesn't exist, just return an empty "list"
        return ""
    end
    return list.nil? ? "" : list
end

def remove_node_from_list(list, node)
    # The "list" as ES stores it is really a string, but array manipulation is easier
    real_list = list.split(",")
    real_list.delete(node)
    return real_list.join(",")
end

def add_node_to_list(list, node)
    if list.size != 0
        list += ","
    end
    list += "#{node}"
    return list
end

def evacuate_node(evacuating_node)
    # To evacuate a node, we need to get a list of all indices. For each index
    # get the current list of excluded nodes, then update the settings with
    # the new node added to that list.
    puts "Evacuating #{evacuating_node}..."
    indices = []
    todays_date = Time.now.strftime("%Y.%m.%d")
    begin
        indices_page = @http.get('/_cat/indices?v')
        indices_page.body.split("\n").drop(1).each do |line|
            indices.push(line.split()[2])
        end
    rescue Exception => e
        puts "Error getting list of indices: #{e}"
    end

    puts "Evacuating #{indices.count} indices from #{evacuating_node} ..."

    indices.each do |index|
        if index == "logstash-#{todays_date}"
            # There's a bug where moving today's index can hang, so we skip it.
            puts "Skipping today's index #{index}..."
            next
        end
        puts "Evacuating #{index} from #{evacuating_node}..."
        # The sleeps are to avoid killing the master
        sleep 10
        begin
            index_settings_page = @http.get("/#{index}/_settings")
            index_settings_hash = JSON.parse(index_settings_page.body)
        rescue Exception => e
            puts "Error getting settings for index #{index}: #{e}"
            next
        end

        exclude_list = get_settings_node_list(index_settings_hash, index, 'exclude')
        include_list = get_settings_node_list(index_settings_hash, index, 'include')

        begin
            if not exclude_list.include?(evacuating_node)
                exclude_list = add_node_to_list(exclude_list, evacuating_node)
                settings_json = JSON.generate({ 'index' => { 'routing' => { 'allocation' => { 'exclude' => { '_host' => "#{exclude_list}" } } } } })
                response = @http.put("/#{index}/_settings", settings_json)
                puts "#{response.body} (#{response.code} #{response.message})"
            end
        rescue Exception => e
            puts "Error setting new exclude list for index #{index}: #{e}"
            puts "Waiting 10 seconds before continuing..."
            sleep 10
        end
        begin
            if include_list.include?(evacuating_node)
                include_list = remove_node_from_list(include_list, evacuating_node)
                settings_json = JSON.generate({ 'index' => { 'routing' => { 'allocation' => { 'include' => { '_host' => "#{include_list}" } } } } })
                response = @http.put("/#{index}/_settings", settings_json)
                puts "#{response.body} (#{response.code} #{response.message})"
            end
        rescue Exception => e
            puts "Error setting new include list for index #{index}: #{e}"
            puts "Waiting 10 seconds before continuing..."
            sleep 10
        end
    end
end

def invacuate_node(invacuating_node)
    # Invacuating is the opposite of evacuating. It will have to, for each index, ADD the index to the
    # include list AND name sure that it's NOT in the exclude list.
    puts "Invacuating #{invacuating_node}..."
    indices = []
    todays_date = Time.now.strftime("%Y.%m.%d")
    begin
        indices_page = @http.get('/_cat/indices?v')
        indices_page.body.split("\n").drop(1).each do |line|
            indices.push(line.split()[2])
        end
    rescue Exception => e
        puts "Error getting list of indices: #{e}"
    end
    
    indices.each do |index|
        if index == "logstash-#{todays_date}"
            puts "Skipping today's index #{index}..."
            next
        end
        puts "Invacuating #{index} to #{invacuating_node}..."
        sleep 10
        begin
            index_settings_page = @http.get("/#{index}/_settings")
            index_settings_hash = JSON.parse(index_settings_page.body)
        rescue Exception => e
            puts "Error getting settings for index #{index}: #{e}"
            next
        end

        exclude_list = get_settings_node_list(index_settings_hash, index, 'exclude')
        include_list = get_settings_node_list(index_settings_hash, index, 'include')

        begin
            if exclude_list.include?("#{invacuating_node}")
                puts "Removing node from exclude list..."
                exclude_list = remove_node_from_list(exclude_list, invacuating_node)
                settings_json = JSON.generate({ 'index' => { 'routing' => { 'allocation' => { 'exclude' => { '_host' => "#{exclude_list}" } } } } })
                response = @http.put("/#{index}/_settings", settings_json)
                puts "#{response.body} (#{response.code} #{response.message})"
                sleep 10
            end
        rescue Exception => e
            puts "Error setting new exclude list for index #{index}: #{e}"
            puts "Waiting 10 seconds before continuing..."
            sleep 10
        end
        begin
            if not include_list.include?("#{invacuating_node}")
                puts "Adding node to include list..."
                include_list = add_node_to_list(include_list, invacuating_node)
                settings_json = JSON.generate({ 'index' => { 'routing' => { 'allocation' => { 'include' => { '_host' => "#{include_list}" } } } } })
                response = @http.put("/#{index}/_settings", settings_json)
                puts "#{response.body} (#{response.code} #{response.message})"
                sleep 10
            end
        rescue Exception => e
            puts "Error setting new include list for index #{index}: #{e}"
            puts "Waiting 10 seconds before continuing..."
            sleep 10
        end
    end
end

case options[:action]
when /invacuate/
    method = "invacuate_node"
when /evacuate/
    method = "evacuate_node"
else
    puts options[:action]
    puts "Valid actions are 'evacuate' and 'invacuate'."
    exit
end

send(method, options[:host])
