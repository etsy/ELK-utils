require 'logstash/namespace'
require 'logstash/filters/base'

# CrossStitch filter, decodes our cross stitch logs
class LogStash::Filters::Crossstitch < LogStash::Filters::Base

  config_name 'crossstitch'

  config :source, :validate => :string, :default => 'span'
  config :target, :validate => :string, :default => 'span'

  def register
    require 'base64'
    require 'msgpack'
    require 'zlib'
  end # def register

  def filter(event)
    return unless filter?(event)

    begin
      @logger.debug? && @logger.debug('Cross Stitch filter: Reanimating event', :source => @source, :target => @target)
      if event['format'] == "msgp"
        event[@target] = MessagePack.unpack(Base64.decode64(event[@source]))
      elsif event['format'] == "gzip"
        event[@target] = MessagePack.unpack(Zlib::Inflate.inflate(Base64.decode64(event[@source])))
      else
        raise "Format not recognized: #{event['format']}"
      end
      @logger.debug? && @logger.debug('Cross Stitch filter: Reanimated event')
      filter_matched(event)
    rescue => e
      event.tag('_decodefailure')
      @logger.warn('Trouble reanimating', :source => @source, :raw => event[@source], :exception => e)
    end

    @logger.debug? && @logger.debug('Event after reanimating', :event => event)

  end # def filter

  public :register, :filter

end # class LogStash::Filters::Crossstitch
