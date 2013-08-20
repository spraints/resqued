module Resqued
  module Logging
    # Public.
    def self.log_file=(path)
      ENV['RESQUED_LOGFILE'] = File.expand_path(path)
    end

    # Public.
    def self.log_file
      ENV['RESQUED_LOGFILE']
    end

    # Public.
    def log_to_stdout?
      Resqued::Logging.log_file.nil?
    end

    # Public: Re-open all log files.
    def reopen_logs
      # todo
    end

    # Private (in classes that include this module)
    def log(message)
      logging_io.puts "[#{$$} #{Time.now.strftime('%H:%M:%S')}] #{message}"
    end

    # Private (may be overridden in classes that include this module to send output to a different IO)
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
  end
end
