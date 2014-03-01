# encoding: utf-8
# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/rpm/blob/master/LICENSE for complete details.

require 'logger'

module NewRelic
  module Agent
    class AgentLogger

      def initialize(root = "", override_logger=nil)
        NewRelic::Agent.logger.info("DBG: creating AgentLogger")
        create_log(root, override_logger)
        NewRelic::Agent.logger.info("DBG: finished create_log")
        NewRelic::Agent.logger.info("DBG: calling set_log_level!")
        set_log_level!
        NewRelic::Agent.logger.info("DBG: finished set_log_level!")
        NewRelic::Agent.logger.info("DBG: calling set_log_format!")
        set_log_format!
        NewRelic::Agent.logger.info("DBG: finished set_log_format!")

        NewRelic::Agent.logger.info("DBG: calling gather_startup_logs")
        gather_startup_logs
        NewRelic::Agent.logger.info("DBG: finished gather_startup_logs")
      end

      def fatal(*msgs)
        format_and_send(:fatal, msgs)
      end

      def error(*msgs)
        format_and_send(:error, msgs)
      end

      def warn(*msgs)
        format_and_send(:warn, msgs)
      end

      def info(*msgs)
        format_and_send(:info, msgs)
      end

      def debug(*msgs)
        format_and_send(:debug, msgs)
      end

      def log_once(level, key, *msgs)
        return if already_logged.include?(key)

        already_logged[key] = true
        self.send(level, *msgs)
      end

      def is_startup_logger?
        false
      end

      # Use this when you want to log an exception with explicit control over
      # the log level that the backtrace is logged at. If you just want the
      # default behavior of backtraces logged at debug, use one of the methods
      # above and pass an Exception as one of the args.
      def log_exception(level, e, backtrace_level=level)
        @log.send(level, "%p: %s" % [ e.class, e.message ])
        @log.send(backtrace_level) do
          backtrace = e.backtrace
          if backtrace
            "Debugging backtrace:\n" + backtrace.join("\n  ")
          else
            "No backtrace available."
          end
        end
      end

      # Allows for passing exceptions in explicitly, which format with backtrace
      def format_and_send(level, *msgs)
        msgs.flatten.each do |item|
          if ENV['DUMP_LOGS_IMMEDIATELY']
            $stdout.puts "#{level}: #{item}"
          end
          case item
          when Exception then log_exception(level, item, :debug)
          else @log.send(level, item)
          end
        end
      end

      def create_log(root, override_logger)
        NewRelic::Agent.logger.info("DBG: in create_log override_logger = #{override_logger}")
        NewRelic::Agent.logger.info("DBG: agent_enabled = #{::NewRelic::Agent.config[:agent_enabled]}")
        if !override_logger.nil?
          @log = override_logger
        elsif ::NewRelic::Agent.config[:agent_enabled] == false
          NewRelic::Agent.logger.info("DBG: creating NullLogger")
          create_null_logger
          NewRelic::Agent.logger.info("DBG: created NullLogger")
        else
          NewRelic::Agent.logger.info("DBG: wants_stdout? = #{wants_stdout?}")
          if wants_stdout?
            NewRelic::Agent.logger.info("DBG: creating Logger")
            @log = ::Logger.new(STDOUT)
            NewRelic::Agent.logger.info("DBG: created Logger")
          else
            NewRelic::Agent.logger.info("DBG: calling create_log_to_file")
            create_log_to_file(root)
            NewRelic::Agent.logger.info("DBG: finished create_log_to_file")
          end
        end
      end

      def create_log_to_file(root)
        NewRelic::Agent.logger.info("DBG: calling find_or_create_file_path(#{::NewRelic::Agent.config[:log_file_path]}, #{root})")
        path = find_or_create_file_path(::NewRelic::Agent.config[:log_file_path], root)
        NewRelic::Agent.logger.info("DBG: path = #{path}")
        if path.nil?
          NewRelic::Agent.logger.info("DBG: creating Logger for STDOUT")
          @log = ::Logger.new(STDOUT)
          warn("Error creating log directory #{::NewRelic::Agent.config[:log_file_path]}, using standard out for logging.")
        else
          file_path = "#{path}/#{::NewRelic::Agent.config[:log_file_name]}"
          NewRelic::Agent.logger.info("DBG: creating Logger for #{file_path}")
          begin
            @log = ::Logger.new(file_path)
          rescue => e
            @log = ::Logger.new(STDOUT)
            warn("Failed creating logger for file #{file_path}, using standard out for logging.", e)
          end
        end
      end

      def create_null_logger
        @log = ::NewRelic::Agent::NullLogger.new
      end

      def already_logged
        @already_logged ||= {}
        @already_logged
      end

      def wants_stdout?
        ::NewRelic::Agent.config[:log_file_path].upcase == "STDOUT"
      end

      def find_or_create_file_path(path_setting, root)
        for abs_path in [ File.expand_path(path_setting),
                          File.expand_path(File.join(root, path_setting)) ] do
          if File.directory?(abs_path) || (Dir.mkdir(abs_path) rescue nil)
            return abs_path[%r{^(.*?)/?$}]
          end
        end
        nil
      end

      def set_log_level!
        @log.level = AgentLogger.log_level_for(::NewRelic::Agent.config[:log_level])
      end

      LOG_LEVELS = {
        "debug" => ::Logger::DEBUG,
        "info"  => ::Logger::INFO,
        "warn"  => ::Logger::WARN,
        "error" => ::Logger::ERROR,
        "fatal" => ::Logger::FATAL,
      }

      def self.log_level_for(level)
        LOG_LEVELS.fetch(level.to_s.downcase, ::Logger::INFO)
      end

      def set_log_format!
        @hostname = Socket.gethostname
        NewRelic::Agent.logger.info("DBG: hostname = #{@hostname}")
        @prefix = wants_stdout? ? '** [NewRelic]' : ''
        NewRelic::Agent.logger.info("DBG: prefix = #{@prefix}")
        @log.formatter = Proc.new do |severity, timestamp, progname, msg|
          "#{@prefix}[#{timestamp.strftime("%m/%d/%y %H:%M:%S %z")} #{@hostname} (#{$$})] #{severity} : #{msg}\n"
        end
      end

      def gather_startup_logs
        StartupLogger.instance.dump(self)
      end
    end

    # In an effort to not lose messages during startup, we trap them in memory
    # The real logger will then dump its contents out when it arrives.
    class StartupLogger < MemoryLogger
      include Singleton
    end
  end
end
