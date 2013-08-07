require 'resqorn/config'
require 'resqorn/logging'

module Resqorn
  # A listener process. Watches resque queues and forks workers.
  class Listener
    include Resqorn::Logging

    # Configure a new listener object.
    def initialize(options)
      @config_path = options.fetch(:config_path)
      @from_master_pipe = options.fetch(:from_master)
      @to_master_pipe = options.fetch(:to_master)
    end

    # Private: memoizes the worker configuration.
    def config
      @config ||= Config.load_file(@config_path)
    end

    # Private: Write

    # Public: Run the main loop.
    def run
      @listening = true
      trap(:QUIT) { @listening = false }

      write_procline('running')
      load_environment
      listen_for_jobs

      write_procline('shutdown')
      reap_workers
    end

    # Private: Check for workers that have stopped running
    def reap_workers(waitpidflags = 0)
      loop do
        worker_pid, status = Process.waitpid2(-1, waitpidflags)
        return if worker_pid.nil?
        report_worker("-#{worker_pid}")
      end
    rescue Errno::ECHILD
      # All done
    end

    # Private.
    def listen_for_jobs
      # totally fake implementation, good for getting process control worked out.
      while @listening do
        reap_workers(Process::WNOHANG)
        busy_work
        sleep 5
      end
    end

    # Temporary.
    def busy_work
      worker_pid = fork do
        $0 = 'resqorn FAKE WORKER'
        log 'WORK'
        sleep 20
        log 'DONE'
      end
      report_worker("+#{worker_pid},queue_name")
    end

    # Private: Report child process status.
    #
    # Examples:
    #
    #     report_worker("+12345,queue")  # Worker process PID:12345 started, working on a job from "queue".
    #     report_worker("-12345")        # Worker process PID:12345 exited.
    def report_worker(status)
      @to_master_pipe.puts(status)
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
    def write_procline(status)
      $0 = "resqorn listener[#{status}] #{@config_path}"
    end
  end
end
