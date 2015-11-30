require 'logstash/namespace'
require 'logstash/filters/base'

# Derrick filter, for pulling in packet captures from Derrik.
# Currently designed only to work on HTTP captures
class LogStash::Filters::Derrick < LogStash::Filters::Base

  config_name 'derrick'

  config :source, :validate => :string, :default => 'http_headers'
  config :target, :validate => :string, :default => 'http_headers'

  def register
  end # def register

  def filter(event)
    return unless filter?(event)

    begin
        event[@target] = Hash[event[@source].split('%0d%0a').map { |foo| foo.split(': ', 2) }]
    rescue => e
        @logger.info("Unable to parse Derrick line: #{event['message']}")
    end

    filter_matched(event)
  end # def filter

  public :register, :filter

end # class LogStash::Filters::Derrick
