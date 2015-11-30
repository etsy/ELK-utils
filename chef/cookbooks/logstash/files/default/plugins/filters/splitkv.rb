# encoding: utf-8
require "logstash/filters/base"
require "logstash/namespace"
require "cgi"

# This filter helps automatically parse messages (or specific event fields)
# which are of the 'foo=bar' variety.
#
# For example, if you have a log message which contains 'ip=1.2.3.4
# error=REFUSED', you can parse those automatically by configuring:
#
#     filter {
#       kv { }
#     }
#
# The above will result in a message of "ip=1.2.3.4 error=REFUSED" having
# the fields:
#
# * ip: 1.2.3.4
# * error: REFUSED
#
# This is great for postfix, iptables, and other types of logs that
# tend towards 'key=value' syntax.
#
# You can configure any arbitrary strings to split your data on,
# in case your data is not structured using '=' signs and whitespace.
# For example, this filter can also be used to parse query parameters like
# 'foo=bar&baz=fizz' by setting the `field_split` parameter to "&".
class LogStash::Filters::SPLITKV < LogStash::Filters::Base
  config_name "splitkv"

  # A string of characters to trim from the value. This is useful if your
  # values are wrapped in brackets or are terminated with commas (like postfix
  # logs).
  #
  # These characters form a regex character class and thus you must escape special regex
  # characters like '[' or ']' using '\'.
  #
  # For example, to strip '<', '>', '[', ']' and ',' characters from values:
  #
  #     filter {
  #       kv {
  #         trimval => "<>\[\],"
  #       }
  #     }
  config :trimval, :validate => :string

  # A string of characters to trim from the key. This is useful if your
  # keys are wrapped in brackets or start with space.
  #
  # These characters form a regex character class and thus you must escape special regex
  # characters like '[' or ']' using '\'.
  #
  # For example, to strip '<' '>' '[' ']' and ',' characters from keys:
  #
  #     filter {
  #       kv {
  #         trimkey => "<>\[\],"
  #       }
  #     }
  config :trimkey, :validate => :string

  # A string of characters to use as delimiters for parsing out key-value pairs.
  #
  # These characters are strings, not regular expressions.
  #
  #     filter {
  #       splitkv {
  #         field_split => "&"
  #       }
  #     }
  config :field_split, :validate => :string, :default => ' '

  # A string of characters to use as delimiters for identifying key-value
  # relations.
  #
  # These characters are strings, not regular expressions.
  #
  #     filter {
  #       splitkv {
  #         value_split => "="
  #       }
  #     }
  config :value_split, :validate => :string, :default => '='

  # A string to prepend to all of the extracted keys.
  #
  # For example, to prepend arg_ to all keys:
  #
  #     filter { kv { prefix => "arg_" } }
  config :prefix, :validate => :string, :default => ''

  # The field to perform 'key=value' searching on
  #
  # For example, to process the `not_the_message` field:
  #
  #     filter { kv { source => "not_the_message" } }
  config :source, :validate => :string, :default => "message"

  # The name of the container to put all of the key-value pairs into.
  #
  # If this setting is omitted, fields will be written to the root of the
  # event, as individual fields.
  #
  # For example, to place all keys into the event field kv:
  #
  #     filter { kv { target => "kv" } }
  config :target, :validate => :string, :default => 'logdata'

  # The name of the decoder to use, to decode data
  #
  # For example, to call CGI::unescape on values:
  #
  #     filter {
  #       kv {
  #         target => "kv"
  #         decoder => "cgi"
  #       }
  #     }
  config :decoder, :validate => :string

  # Any keys less than 4 chars which you want to preserve.
  #
  #     filter {
  #       kv {
  #         target => "kv"
  #         preserve_keys => [ "foo" ]
  #       }
  #     }
  config :preserve_keys, :validate => :array, :default => []

  config :min_key_length, :validate => :number, :default => 4

  def register
    @trim_re = Regexp.new("[#{@trimval}]") if !@trimval.nil?
    @trimkey_re = Regexp.new("[#{@trimkey}]") if !@trimkey.nil?
  end # def register

  def filter(event)
    return unless filter?(event)

    value = event[@source]

    case value
      when String; kv = parse(value)
      when nil; # Nothing to do
      else
        @logger.warn("kv filter has no support for this type of data",
                     :type => value.class, :value => value)
    end # case value
    if !defined? kv
      return
    end

    # If we have any keys, create/append the hash
    # If @source and @target are the same, just overwrite @target
    if @source == @target
        event[@target] = kv
    # If @target exists and 
    elsif event[@target].is_a?(Hash) && kv.is_a?(Hash)
        event[@target].merge!(kv)
    elsif kv.is_a?(Hash)
        event[@target] = kv
    end
    filter_matched(event)
  end # def filter

  private
  def parse(text)
    if !text =~ /[@field_split]/
      return
    end
    
    # At some point we want to be able to preserve duplicate entries when key
    # names collide (eg:  [[foo, bar], [foo, baz]}).
    # The solution is outlined here, to use .with_object:
    # http://stackoverflow.com/questions/23659947/ruby-convert-array-to-hash-preserve-duplicate-key
    kvarray = text.split(@field_split).map { |afield|
      pairs = afield.split(@value_split)
      if pairs[0].nil? || !(pairs[0] =~ /^[0-9]/).nil? || (pairs[0].length < @min_key_length && !@preserve_keys.include?(pairs[0]))
          next
      end
      if !pairs[1].nil?
        if @decoder == 'cgi'
          # cgi decoding on ~25 fields increases time from 0.23s to 1.07s
          pairs[1] = CGI::unescape(pairs[1])
        end
        if !@trimkey.nil?
          # 2 if's are faster (0.26s) than gsub (0.33s)
          #pairs[0] = pairs[0].slice(1..-1) if pairs[0].start_with?(@trimkey)
          #pairs[0].chop! if pairs[0].end_with?(@trimkey)
          #
          # BUT! in-place tr is 6% faster than 2 if's (0.52s vs 0.55s)
          pairs[0].tr!(@trimkey, '') if pairs[0].start_with?(@trimkey)
        end
        if !@trimval.nil?
          # 2 if's are faster (0.26s) than gsub (0.33s)
          #pairs[1] = pairs[1].slice(1..-1) if pairs[1].start_with?(@trimval)
          #pairs[1].chop! if pairs[1].end_with?(@trimval)
          #
          # BUT! in-place tr is 6% faster than 2 if's (0.52s vs 0.55s)
          pairs[1].tr!(@trimval, '') if pairs[1].start_with?(@trimval)
        end
      end
      pairs
    }
    kvarray.delete_if { |x| x == nil }
    return Hash[kvarray]
  end
end # class LogStash::Filters::SPLITKV
