require 'resqorn/config'
require 'resqorn/logging'
require 'resqorn/sleepy'
require 'resqorn/worker'

module Resqorn
  # A listener process. Watches resque queues and forks workers.
  class Listener
    include Resqorn::Logging
    include Resqorn::Sleepy

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

    SIGNALS = [ :QUIT, :CHLD ]

    SIGNAL_QUEUE = []

    # Public: Run the main loop.
    def run
      SIGNALS.each { |signal| trap(signal) { SIGNAL_QUEUE << signal ; awake } }

      write_procline('running')
      load_environment
      init_workers
      run_workers_run

      write_procline('shutdown')
      @from_master_pipe.close
      reap_workers
    end

    # Private.
    def run_workers_run
      loop do
        reap_workers(Process::WNOHANG)
        check_for_expired_workers
        start_idle_workers
        case signal = SIGNAL_QUEUE.shift
        when nil
          yawn(60.0)
        when :QUIT
          workers.each { |worker| worker.kill(signal) }
        end
      end
    end

    # Private: all available workers
    attr_reader :workers

    # Private.
    def yawn(duration)
      super(duration, @from_master_pipe)
    end

    # Private: Check for workers that have stopped running
    def reap_workers(waitpidflags = 0)
      loop do
        worker_pid, status = Process.waitpid2(-1, waitpidflags)
        return if worker_pid.nil?
        finish_worker(worker_pid, status)
        report_to_master("-#{worker_pid}")
      end
    rescue Errno::ECHILD
      # All done
    end

    # Private: Check if master reports any dead workers.
    def check_for_expired_workers
      loop do
        IO.select([@from_master_pipe], nil, nil, 0) or return
        line = @from_master_pipe.readline
        finish_worker(line.to_i, nil)
      end
    end

    # Private.
    def finish_worker(worker_pid, status)
      workers.each do |worker|
        if worker.pid == worker_pid
          worker.finished!(status)
        end
      end
    end

    # Private.
    def start_idle_workers
      workers.each do |worker|
        if worker.idle?
          worker.try_start
          report_to_master("+#{worker.pid},#{worker.queue_key}")
        end
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
        if blocked_worker = workers.detect { |worker| worker.idle? && worker.queue_key == running_worker[:queue]) }
          blocked_worker.wait_for(running_worker[:pid].to_i)
        end
      end
      @workers = workers
    end

    # Private: Report child process status.
    #
    # Examples:
    #
    #     report_to_master("+12345,queue")  # Worker process PID:12345 started, working on a job from "queue".
    #     report_to_master("-12345")        # Worker process PID:12345 exited.
    def report_to_master(status)
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
