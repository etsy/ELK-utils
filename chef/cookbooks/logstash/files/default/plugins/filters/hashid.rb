require 'logstash/namespace'
require 'logstash/filters/base'
require 'digest'
require 'securerandom'

# A replacement for the uuid filter, which generates a hash for use as the `_id`
# in your output.
# This is useful to be able to control the `_id` messages are indexed into
# Elasticsearch with, so that you can insert duplicate messages (i.e. the same
# message multiple times without creating duplicates).
#
# In the event that your source field doesn't exist, a random UUID will be
# generated using SecureRandom.uuid
#
# Based on
# http://blog.mikemccandless.com/2014/05/choosing-fast-unique-identifier-uuid.html,
# it may be better to generate this ID using UUID-V1, or something else, in
# future.
#
class LogStash::Filters::Hashid < LogStash::Filters::Base
    config_name 'hashid'

    # Source field for the hash
    #
    # Example:
    # [source,ruby]
    #     filter {
    #       hashid {
    #         source => "message"
    #       }
    #     }
    config :source, :validate => :string, :default => 'message'

    # Add a hash to a field.
    #
    # Example:
    # [source,ruby]
    #     filter {
    #       hashid {
    #         target => "[@metadata][@uuid]"
    #       }
    #     }
    config :target, :validate => :string, :default => '[@metadata][@hashid]'

    # If the value in the field currently (if any) should be overridden
    # by the generated UUID. Defaults to `false` (i.e. if the field is
    # present, with ANY value, it won't be overridden)
    #
    # Example:
    # [source,ruby]
    #    filter {
    #      uuid {
    #        target    => "@uuid"
    #        overwrite => true
    #      }
    #    }
    config :overwrite, :validate => :boolean, :default => false

  def register
  end # def register

  def filter(event)
    return unless filter?(event)

    if event[source]
        hash = Digest::SHA1.hexdigest(event[source])
    else
        hash = SecureRandom.uuid
    end
    if overwrite
        event[target] = hash
    else
        event[target] ||= hash
    end

    filter_matched(event)
  end # def filter

end # class LogStash::Filters::Hashid
