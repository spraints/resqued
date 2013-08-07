require 'resqorn/config'

module Resqorn
  # A listener process. Watches resque queues and forks workers.
  class Listener
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
      listen_for_jobs
    end

    # Private.
    def listen_for_jobs
      # totally fake implementation, good for getting process control worked out.
      loop do
        sleep 5
        fork do
          puts "[#$$ #{Time.now.strftime('%H:%M:%S')}] WORK"
          sleep 20
          puts "[#$$ #{Time.now.strftime('%H:%M:%S')}] DONE"
        end
      end
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
