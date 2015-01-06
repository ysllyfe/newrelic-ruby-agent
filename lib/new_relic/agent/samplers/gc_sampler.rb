require 'rbconfig'
require 'new_relic/agent/sampler'

module NewRelic
  module Memstats
    class GcSampler < Agent::Sampler
      named :memstats

      def platform
        RbConfig::CONFIG['target_os']
      end

      def get_rss_bytes
        if defined? JRuby
          get_rss_bytes_jvm
        elsif platform =~ /linux/
          get_rss_bytes_proc
        else
          get_rss_bytes_ps
        end
      end

      def get_rss_bytes_jvm
        java.lang.Runtime.getRuntime.totalMemory.to_f rescue nil
      end

      def get_rss_bytes_ps
        case platform
        when /darwin9/   # 10.5
          base_cmd = "ps -o rsz"
        when /darwin1\d+/ # >= 10.6
          base_cmd = "ps -o rss"
        when /freebsd/
          base_cmd = "ps -o rss"
        when /solaris/
          base_cmd = "/usr/bin/ps -o rss -p"
        end
        return nil unless base_cmd

        `#{base_cmd} #{$$}`.split("\n")[1].to_f * 1024.0 rescue nil
      end

      def get_rss_bytes_proc
        proc_status = proc_try_read("/proc/#{$$}/status")
        if proc_status && proc_status =~ /RSS:\s*(\d+) kB/i
          return $1.to_f * 1024.0
        end
        return nil
      end

      # A File.read against /(proc|sysfs)/* can hang with some older Linuxes.
      # See https://bugzilla.redhat.com/show_bug.cgi?id=604887, RUBY-736, and
      # https://github.com/opscode/ohai/commit/518d56a6cb7d021b47ed3d691ecf7fba7f74a6a7
      # for details on why we do it this way.
      def proc_try_read(path)
        return nil unless File.exist?(path)
        content = ''
        File.open(path) do |f|
          loop do
            begin
              content << f.read_nonblock(4096)
            rescue EOFError
              break
            rescue Errno::EWOULDBLOCK, Errno::EAGAIN
              content = nil
              break # don't select file handle, just give up
            end
          end
        end
        content
      end

      def poll
        rss_bytes = get_rss_bytes
        event = GC.stat.merge(:pid => Process.pid, :rss_bytes => rss_bytes)
        Agent.record_custom_event(:RubyGCStats, event)
      end
    end
  end
end
