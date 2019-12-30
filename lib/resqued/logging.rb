require "mono_logger"

module Resqued
  # Mixin for any class that wants to write messages to the log file.
  module Logging
    # Global logging state.
    class << self
      # Public: Get a `Logger`.
      def logger
        @logger ||= build_logger
      end

      def build_logger
        MonoLogger.new(ResquedLoggingIOWrapper.new).tap do |logger|
          logger.formatter = ResquedLogFormatter.new
        end
      end

      class ResquedLogFormatter < ::Logger::Formatter
        def call(severity, time, progname, msg)
          sprintf "[%s#%6d] %5s %s -- %s\n",
                  format_datetime(time),
                  $$,
                  severity,
                  progname,
                  msg2str(msg)
        end
      end

      # Private: Lets our logger reopen its logfile without monologger EVEN KNOWING.
      class ResquedLoggingIOWrapper
        # rubocop: disable Style/MethodMissingSuper
        def method_missing(*args)
          ::Resqued::Logging.logging_io.send(*args)
        end
        # rubocop: enable Style/MethodMissingSuper

        def respond_to_missing?(method, *)
          ::Resqued::Logging.logging_io.respond_to?(method)
        end
      end

      # Private: Get an IO to write log messages to.
      def logging_io
        @logging_io = nil if @logging_io&.closed?
        @logging_io ||=
          if path = Resqued::Logging.log_file
            File.open(path, "a").tap do |f|
              f.sync = true
              f.close_on_exec = true
              # Make sure we're not holding onto a stale filehandle.
              $stdout.reopen(f)
              $stderr.reopen(f)
            end
          else
            $stdout
          end
      end

      # Public: Make sure the log IO is closed.
      def close_log
        if @logging_io && @logging_io != $stdout
          @logging_io.close
          @logging_io = nil
        end
      end

      # Public.
      def log_file=(path)
        ENV["RESQUED_LOGFILE"] = File.expand_path(path)
        close_log
      end

      # Public.
      def log_file
        ENV["RESQUED_LOGFILE"]
      end
    end

    # Public.
    def log_to_stdout?
      Resqued::Logging.log_file.nil?
    end

    # Public: Re-open all log files.
    def reopen_logs
      Resqued::Logging.close_log # it gets opened the next time it's needed.
    end

    # Private (in classes that include this module)
    def log(level, message = nil)
      level, message = :info, level if message.nil?
      Resqued::Logging.logger.send(level, self.class.name) { message }
    end
  end
end
