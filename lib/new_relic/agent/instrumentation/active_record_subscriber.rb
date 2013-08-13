# encoding: utf-8
# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/rpm/blob/master/LICENSE for complete details.
require 'new_relic/agent/instrumentation/active_record_helper'

# Listen for ActiveSupport::Notifications events for ActiveRecord query
# events.  Write metric data, transaction trace segments and slow sql
# nodes for each event.
module NewRelic
  module Agent
    module Instrumentation
      class ActiveRecordSubscriber
        include NewRelic::Agent::Instrumentation

        def self.subscribed?
          # TODO: need to talk to Rails core about an API for this,
          # rather than digging through Listener ivars
          ActiveSupport::Notifications.notifier.listeners_for('sql.active_record') \
            .find{|l| l.instance_variable_get(:@delegate).class == self }
        end

        def call(*args)
          ::NewRelic::Agent.logger.info("ActiveRecordSubscriber#call - traced? = #{NewRelic::Agent.is_execution_traced?.inspect}")
          return unless NewRelic::Agent.is_execution_traced?

          ::NewRelic::Agent.logger.info("Creating event from AR 4 notification")
          event = ActiveSupport::Notifications::Event.new(*args)
          record_metrics(event)
          ::NewRelic::Agent.logger.info("Noticing SQL for AR 4")
          notice_sql(event)
        end

        def get_explain_plan( config, query )
          connection = NewRelic::Agent::Database.get_connection(config) do
            ::ActiveRecord::Base.send("#{config[:adapter]}_connection",
                                      config)
          end
          if connection && connection.respond_to?(:execute)
            return connection.execute("EXPLAIN #{query}")
          end
        end

        def notice_sql(event)
          config = active_record_config_for_event(event)
          metric = base_metric(event)

          # enter transaction trace segment
          ::NewRelic::Agent.logger.info("Entering TT segment for '#{metric}' at #{event.time}")
          scope = NewRelic::Agent.instance.stats_engine.push_scope(:active_record, event.time)

          NewRelic::Agent.instance.transaction_sampler \
            .notice_sql(event.payload[:sql], config,
                        Helper.milliseconds_to_seconds(event.duration),
                        &method(:get_explain_plan))

          NewRelic::Agent.instance.sql_sampler \
            .notice_sql(event.payload[:sql], metric, config,
                        Helper.milliseconds_to_seconds(event.duration),
                        &method(:get_explain_plan))

          # exit transaction trace segment
          ::NewRelic::Agent.logger.info("Exiting TT segment for '#{metric}' at #{event.end}")
          NewRelic::Agent.instance.stats_engine.pop_scope(scope, metric, event.end)
        end

        def record_metrics(event)
          ::NewRelic::Agent.logger.info("Recording metrics for AR 4 event, duration = #{event.duration} ms")
          base = base_metric(event)
          ::NewRelic::Agent.logger.info("AR 4 event base metric name = #{base}")
          NewRelic::Agent.instance.stats_engine.record_metrics(base,
                              Helper.milliseconds_to_seconds(event.duration),
                              :scoped => true)

          other_metrics = ActiveRecordHelper.rollup_metrics_for(base)
          ::NewRelic::Agent.logger.info("Recording AR 4 rollup metrics: #{other_metrics.inspect}")
          if config = active_record_config_for_event(event)
            other_metrics << ActiveRecordHelper.remote_service_metric(config[:adapter], config[:host])
          end

          other_metrics.compact.each do |metric_name|
            NewRelic::Agent.instance.stats_engine.record_metrics(metric_name,
                                            Helper.milliseconds_to_seconds(event.duration),
                                            :scoped => false)
          end
        end

        def base_metric(event)
          ActiveRecordHelper.metric_for_name(event.payload[:name]) ||
            ActiveRecordHelper.metric_for_sql(NewRelic::Helper.correctly_encoded(event.payload[:sql]))
        end

        def active_record_config_for_event(event)
          return unless event.payload[:connection_id] && NewRelic::LanguageSupport.object_space_enabled?

          # TODO: This will not work for JRuby and in any case we want
          # this to be part of the event meta data so it doesn't have
          # to be dug out of an ivar.
          connection = ObjectSpace._id2ref(event.payload[:connection_id])
          connection.instance_variable_get(:@config) if connection
        end
      end
    end
  end
end
