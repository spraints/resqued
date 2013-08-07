require 'resqorn/config'
require 'resqorn/logging'

module Resqorn
  # A listener process. Watches resque queues and forks workers.
  class Listener
    include Resqorn::Logging

    def initialize(options)
      @config_path = options.fetch(:config_path)
    end

    def config
      @config ||= Config.load_file(@config_path)
    end

    def run(process_log = $stdout)
      write_procline
      #install_signal_handlers
      load_environment
      listen_for_jobs(process_log)
    end

    # Private.
    def listen_for_jobs(process_log)
      # totally fake implementation, good for getting process control worked out.
      loop do
        busy_work(process_log)
        sleep 5
      end
    end

    # Temporary.
    def busy_work(process_log)
      @worker_pid = fork do
        log 'WORK'
        sleep 20
        log 'DONE'
      end
      process_log.puts "#@worker_pid,queue_name"
      process_log.puts "#@worker_pid,queue_name"
    end

    # Private: load the application.
    #
    # To do:
    # * Does this reload correctly if the bundle changes and `bundle exec resqorn config/resqorn.rb`?
    # * Maybe make the specific app environment configurable (i.e. load rails, load rackup, load some custom thing)
    def load_environment
      require File.expand_path('config/environment.rb')
    end

    # Private.
    def write_procline
      $0 = "resqorn listener #{@config_path}"
    end
  end
end
