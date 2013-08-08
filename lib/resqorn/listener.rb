require 'resqorn/config'
require 'resqorn/logging'
require 'resqorn/worker'

module Resqorn
  # A listener process. Watches resque queues and forks workers.
  class Listener
    include Resqorn::Logging

    # Configure a new listener object.
    def initialize(options)
      @config_path = options.fetch(:config_path)
      @running_workers = options.fetch(:running_workers) { [] }
      @from_master_pipe = options.fetch(:from_master)
      @to_master_pipe = options.fetch(:to_master)
    end

    # Private: memoizes the worker configuration.
    def config
      @config ||= Config.load_file(@config_path)
    end

    # Public: Run the main loop.
    def run
      @listening = true
      trap(:QUIT) { @listening = false }

      write_procline('running')
      load_environment
      listen_for_jobs

      write_procline('shutdown')
      @from_master_pipe.close
      reap_workers
    end

    # Private: all available workers
    def workers
      @workers ||= init_workers
    end

    # Private: Check for workers that have stopped running
    def reap_workers(waitpidflags = 0)
      loop do
        worker_pid, status = Process.waitpid2(-1, waitpidflags)
        return if worker_pid.nil?
        workers.each do |worker|
          if worker.pid == worker_pid
            worker.finished!(status)
          end
        end
        report_worker("-#{worker_pid}")
      end
    rescue Errno::ECHILD
      # All done
    end

    # Private.
    def listen_for_jobs
      while @listening do
        reap_workers(Process::WNOHANG)
        workers.each do |worker|
          if worker.idle?
            worker.try_start
          end
        end
        sleep 5
      end
    end

    # Private.
    def init_workers
      workers = []
      config.workers.each do |worker_config|
        worker_config[:size].times do
          workers << Worker.new(worker_config)
        end
      end
      @running_workers.each do |running_worker|
        if blocked_worker = workers.detect { |worker| worker.idle? && worker.watches_queue?(running_worker[:queue]) }
          blocked_worker.wait_for(running_worker[:pid])
        end
      end
      workers
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
      Rails.application.eager_load!
    end

    # Private.
    def write_procline(status)
      $0 = "resqorn listener[#{status}] #{@config_path}"
    end
  end
end
