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
    opts.on('-i', '--index I', String, "Specify an index to evacuate, (default is all indices)") { |v| options[:index] = v }
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
        e = ""
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

def get_indices(options)
    indices = []
    if !options[:index].nil?
        indices = options[:index].split(',')
    else
        begin
            indices_page = @http.get('/_cat/indices?v')
            indices_page.body.split("\n").drop(1).each do |line|
                indices.push(line.split()[2])
            end
        rescue Exception => e
            puts "Error getting list of indices: #{e}"
        end
    end
    indices.sort!
    return indices
end

def get_index_settings(index)
    begin
        index_settings_page = @http.get("/#{index}/_settings")
        index_settings_hash = JSON.parse(index_settings_page.body)
    rescue Exception => e
        puts "Error getting settings for index #{index}: #{e}"
    end
    return index_settings_hash
end

def update_settings(index, settings_hash)
    settings_json = JSON.generate(settings_hash)

    begin
        response = @http.put("/#{index}/_settings", settings_json)
        puts "#{response.body} (#{response.code} #{response.message})"
    rescue Exception => e
        puts "Error setting new exclude list for index #{index}: #{e}"
        puts "Waiting 10 seconds before continuing..."
        sleep 10
    end
end

def evacuate_node(evacuating_node, indices)
    # To evacuate a node, we need to get a list of all indices. For each index
    # get the current list of excluded nodes, then update the settings with
    # the new node added to that list.
    puts "Evacuating #{evacuating_node}..."

    puts "Evacuating #{indices.count} indices from #{evacuating_node} ..."

    indices.each do |index|
        puts "Evacuating #{index} from #{evacuating_node}..."
        # The sleeps are to avoid killing the master
        index_settings_hash = get_index_settings(index)
        exclude_list = get_settings_node_list(index_settings_hash, index, 'exclude')
        include_list = get_settings_node_list(index_settings_hash, index, 'include')
        do_update = false

        allocation_hash = { 'index' => { 'routing' => { 'allocation' => {} } } }
        if not exclude_list.include?(evacuating_node)
            puts "Adding node to exclude list..."
            exclude_list = add_node_to_list(exclude_list, evacuating_node)
            allocation_hash['index']['routing']['allocation']['exclude'] = { '_host' => "#{exclude_list}" }
            do_update = true
        end
        if include_list.include?(evacuating_node)
            puts "Removing node from include list..."
            include_list = remove_node_from_list(include_list, evacuating_node)
            allocation_hash['index']['routing']['allocation']['include'] = { '_host' => "#{include_list}" }
            do_update = true
        end
        if do_update
            update_settings(index, allocation_hash)
        else
            puts "No change to include or exclude lists for #{index}"
        end
    end
end

def invacuate_node(invacuating_node, indices)
    # Invacuating is the opposite of evacuating. It will have to, for each index, ADD the index to the
    # include list AND name sure that it's NOT in the exclude list.
    puts "Invacuating #{invacuating_node}..."

    indices.each do |index|
        puts "Invacuating #{index} to #{invacuating_node}..."
        index_settings_hash = get_index_settings(index)
        exclude_list = get_settings_node_list(index_settings_hash, index, 'exclude')
        include_list = get_settings_node_list(index_settings_hash, index, 'include')
        do_update = false

        allocation_hash = { 'index' => { 'routing' => { 'allocation' => {} } } }
        if exclude_list.include?(invacuating_node)
            puts "Removing node from exclude list..."
            exclude_list = remove_node_from_list(exclude_list, invacuating_node)
            allocation_hash['index']['routing']['allocation']['exclude'] = { '_host' => "#{exclude_list}" }
            do_update = true
        end
        if not include_list.include?(invacuating_node)
            puts "Adding node to include list..."
            include_list = add_node_to_list(include_list, invacuating_node)
            allocation_hash['index']['routing']['allocation']['include'] = { '_host' => "#{include_list}" }
            do_update = true
        end
        if do_update
            update_settings(index, allocation_hash)
        else
            puts "No change to include or exclude lists for #{index}"
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

indices = get_indices(options)

send(method, options[:host], indices)
