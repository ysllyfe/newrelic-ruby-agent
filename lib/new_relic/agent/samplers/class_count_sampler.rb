require 'new_relic/agent/sampler'

module NewRelic
  module Memstats
    class ClassCountSampler < Agent::Sampler
      named :class_count

      def self.supported_on_this_platform?
        ObjectSpace.respond_to?(:count_objects)
      end

      def poll
        event = ObjectSpace.count_objects.merge(:pid => Process.pid)
        Agent.record_custom_event(:RubyObjectTypeCounts, event)
      end
    end
  end
end
