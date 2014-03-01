# encoding: utf-8
# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/rpm/blob/master/LICENSE for complete details.

# Base class for startup logging and testing in multiverse

module NewRelic
  module Agent
    class MemoryLogger
      def initialize
        @messages = []
      end

      def is_startup_logger?
        true
      end

      attr_accessor :messages, :level

      def fatal(*msgs)
        messages << [:fatal, msgs]
        dump_messages_to_stderr
      end

      def error(*msgs)
        messages << [:error, msgs]
        dump_messages_to_stderr
      end

      def warn(*msgs)
        messages << [:warn, msgs]
        dump_messages_to_stderr
      end

      def info(*msgs)
        messages << [:info, msgs]
        dump_messages_to_stderr
      end

      def debug(*msgs)
        messages << [:debug, msgs]
        dump_messages_to_stderr
      end

      def log_exception(level, e, backtrace_level=level)
        messages << [:log_exception, [level, e, backtrace_level]]
        dump_messages_to_stderr
      end

      def dump_messages_to_stderr
        return unless ENV['DUMP_LOGS_IMMEDIATELY']
        until messages.empty?
          (level, msgs) = messages.pop
          msgs.each do |m|
            $stdout.puts "#{level}: #{m}"
          end
        end
      end

      def dump(logger)
        NewRelic::Agent.logger.info("DBG: dumping from StartupLogger to #{logger}")
        messages.each do |(method, args)|
          NewRelic::Agent.logger.info("DBG: dumping #{method} with #{args}")
          logger.send(method, *args)
        end
        messages.clear
      end
    end
  end
end
