# encoding: utf-8
# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/rpm/blob/master/LICENSE for complete details.

require 'new_relic/agent/sampler'

module NewRelic
  module Agent
    module Samplers
      class ObjectSampler < NewRelic::Agent::Sampler
        def initialize
          super :objects
          @last_allocation_count = ObjectSpace.allocated_objects
        end

        def self.supported_on_this_platform?
          defined?(ObjectSpace) && ObjectSpace.respond_to?(:live_objects) && ObjectSpace.respond_to?(:allocated_objects)
        end

        def poll
          live_objects = ObjectSpace.live_objects
          allocated_objects = ObjectSpace.allocated_objects
          allocation_delta = allocated_objects - @last_allocation_count
          NewRelic::Agent.record_metric("GC/objects", live_objects)
          NewRelic::Agent.record_metric("GC/object_allocations", allocation_delta)
          @last_allocation_count = allocated_objects
        end
      end
    end
  end
end
