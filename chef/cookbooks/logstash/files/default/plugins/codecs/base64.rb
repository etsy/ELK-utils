# encoding: utf-8
require "logstash/codecs/base"

class LogStash::Codecs::Base64 < LogStash::Codecs::Base
  config_name "base64"

  milestone 1

  config :format, :validate => :string, :default => nil

  public
  def register
    require "base64"
  end

  public
  def decode(data)
    begin
      event = LogStash::Event.new(Base64.decode(data))
      event["@timestamp"] = Time.at(event["@timestamp"]).utc if event["@timestamp"].is_a? Float
      event["tags"] ||= []
      if @format
        event["message"] ||= event.sprintf(@format)
      end
    rescue => e
      # Treat as plain text and try to do the best we can with it?
      @logger.warn("Trouble parsing base64 input, falling back to plain text",
                   :input => data, :exception => e)
      event["message"] = data
      event["tags"] ||= []
      event["tags"] << "_base64parsefailure"
    end
    yield event
  end # def decode

  public
  def encode(event)
    event["@timestamp"] = event["@timestamp"].to_f
    @on_event.call(Base64.encode64(event))
  end # def encode

end # class LogStash::Codecs::Msgpack
