module Resqued
  module Logging
    # Global logging state.
    class << self
      # Public: Get an IO to write log messages to.
      def logging_io
        @logging_io = nil if @logging_io && @logging_io.closed?
        @logging_io ||=
          if path = Resqued::Logging.log_file
            File.open(path, 'a').tap do |f|
              f.sync = true
              f.close_on_exec = true
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
        ENV['RESQUED_LOGFILE'] = File.expand_path(path)
        close_log
      end

      # Public.
      def log_file
        ENV['RESQUED_LOGFILE']
      end
    end

    # Public.
    def log_to_stdout?
      Resqued::Logging.log_file.nil?
    end

    # Public: Re-open all log files.
    def reopen_logs
      Resqued::Logging.close_log # it gets reopened the next time it gets used.
    end

    # Private (in classes that include this module)
    def log(message)
      Resqued::Logging.logging_io.puts "[#{$$} #{Time.now.strftime('%H:%M:%S')}] #{message}"
    end
  end
end
