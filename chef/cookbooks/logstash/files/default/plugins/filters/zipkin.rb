require 'logstash/namespace'
require 'logstash/filters/base'

# Zipkin filter
class LogStash::Filters::Zipkin < LogStash::Filters::Base

  config_name 'zipkin'

  config :source, :validate => :string, :default => 'span'
  config :target, :validate => :string, :default => 'span'

  def register
    require 'base64'
    require 'set'
    require 'ipaddr'
    require 'json'

    require 'thrift'
    require 'finagle-thrift'
  end # def register

  def filter(event)
    return unless filter?(event)

    begin
      @logger.debug('Zipkin filter: Reanimating event', :source => @source)
      event[@target] = to_xstitch(deserialize_span(event[@source]))
      @logger.debug('Zipkin filter: Reanimated event', :target => @target)
      filter_matched(event)
    rescue => e
      event.tag('_decodefailure')
      @logger.warn('Trouble reanimating', :source => @source, :raw => event[@source], :exception => e)
    end

    @logger.debug? && @logger.debug('Event after reanimating', :event => event)

  end # def filter

  public :register, :filter

  private

  def deserialize_span(str)
    deserializer = Thrift::Deserializer.new
    deserializer.deserialize(FinagleThrift::Span.new, Base64.strict_decode64(str))
  end

  # @param [Span] span
  def to_xstitch(span)
    {
        'span_id' => to_xstitch_id(span.id),
        'parent_id' => to_xstitch_id(span.parent_id),
        'root_id' => to_xstitch_id(span.trace_id),
        'name' => span.name,
        # denormalized for cross-stitch & search purposes from annotations' endpoint info
        'service' => (services_from_annotations(span.annotations) | services_from_annotations(span.binary_annotations)),
        'annotations' => span.annotations.map do |a|
          {
              'timestamp' => a.timestamp,
              'value' => a.value,
              'duration' => a.duration,
              'endpoint' => to_xstitch_endpoint(a.host),
          }
        end,
        'binary_annotations' => span.binary_annotations.map do |a|
          {
              a.key => convert_binary(a.annotation_type, a.value),
              'endpoint' => to_xstitch_endpoint(a.host),
          }
        end,
        'debug' => span.debug,
    }
  end

  def to_xstitch_id(id)
    if id.nil?
      nil
    else
      unsigned_id = to_unsigned(id, 64)
      hi = unsigned_id >> 32
      lo = unsigned_id & 0xFFFFFFFF
      bytes = [hi, lo].pack('N2')
      Base64.urlsafe_encode64(bytes).slice(0, 11)
    end
  end

  def to_xstitch_endpoint(endpoint)
    if endpoint.nil?
      nil
    else
      ip_str = IPAddr.new(to_unsigned(endpoint.ipv4, 32), Socket::AF_INET)
      "#{endpoint.service_name}@#{ip_str}:#{to_unsigned(endpoint.port, 16)}"
    end
  end

  def to_signed(n, bits)
    mask = (1 << (bits - 1))
    (n & ~mask) - (n & mask)
  end

  def to_unsigned(n, bits)
    if n < 0
      n + (1 << bits)
    else
      n
    end
  end

  def convert_binary(type, bytes)
    case type
      when FinagleThrift::AnnotationType::BOOL
        bytes == '\x0'
      when FinagleThrift::AnnotationType::I16
        to_signed(bytes.unpack('n').first, 16)
      when FinagleThrift::AnnotationType::I32
        to_signed(bytes.unpack('N').first, 32)
      when FinagleThrift::AnnotationType::I64
        hi, lo = bytes.unpack('N2')
        to_signed(hi << 32 | lo, 64)
      when FinagleThrift::AnnotationType::DOUBLE
        bytes.unpack('G').first
      when FinagleThrift::AnnotationType::STRING
        bytes
      else # BYTES or an unknown annotation type
        bytes.unpack('H*').first # Hexlify
    end
  end

  def services_from_annotations(annotations)
    services = Set.new
    annotations.each do |a|
      if a.host
        services << a.host.service_name
      end
    end
    services.to_a
  end

end # class LogStash::Filters::Zipkin
