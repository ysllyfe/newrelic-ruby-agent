# encoding: utf-8
# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/rpm/blob/master/LICENSE for complete details.

require 'new_relic/agent/sampler'

module NewRelic
  module Agent
    module Samplers
      class InsightsMemorySampler < NewRelic::Agent::Sampler
        named :insights_memory

        def self.supported_on_this_platform?
          GC.respond_to?(:stat)
        end

        def poll
          event = {
            :pid => $$,
            :rss => ::NewRelic::Agent::SystemInfo.get_rss
          }
          event.merge!(GC.stat)
          ::NewRelic::Agent.record_custom_event(:RubyGCStat, event)
        end
      end
    end
  end
end
