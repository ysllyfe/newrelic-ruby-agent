require 'new_relic/agent/sampler'

module NewRelic
  module Agent
    module Samplers
      class ObjectSampler < NewRelic::Agent::Sampler

        def initialize
          super :objects
          @last_allocation_count = ObjectSpace.allocated_objects
        end

        def stats
          stats_engine.get_stats_no_scope("GC/objects")
        end

        def allocated_object_stats
          stats_engine.get_stats_no_scope("GC/object_allocations")
        end

        def self.supported_on_this_platform?
          defined?(ObjectSpace) && ObjectSpace.respond_to?(:live_objects) && ObjectSpace.respond_to?(:allocated_objects)
        end

        def poll
          stats.record_data_point(ObjectSpace.live_objects)

          allocated_objects = ObjectSpace.allocated_objects
          allocation_delta = allocated_objects - @last_allocation_count
          allocated_object_stats.record_data_point(allocation_delta)
          @last_allocation_count = allocated_objects
        end
      end
    end
  end
end
