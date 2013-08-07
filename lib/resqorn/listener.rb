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
      SIGNALS.each { |signal| trap(signal) { SIGNAL_QUEUE << signal ; awaken } }

      write_procline('running')
      spin_up_workers
      loop do
        recycle_workers
        case signal << SIGNAL_QUEUE.shift
        when nil
          yawn(30.0)
        when :QUIT
          write_procline('shutdown')
          @from_master_pipe.close
          kill_all_workers(signal)
          wait_for_shutdown
          return
        end
      end
    end

    # Private.
    def spin_up_workers
      running_workers = @running_workers.each_with_object(Hash.new { |h,k| h[k] = [] }) { |running_worker, h| h[running_worker[:queue]] << running_worker[:pid] }
      @running_workers = {} # pid of resque worker => worker that should be running
      @waiting_workers = {} # pid of old worker    => worker to start
      @stopped_workers = []
      config.workers.each do |worker_config|
        worker_config[:size].times do
          worker = Worker.new(worker_config)
          queues = worker_config[:queues].sort.join(',')
          #queues = worker.queue_key
          if old_pid = running_workers[queues]
            @waiting_workers[old_pid] = worker
          else
            @stopped_workers << worker
          end
        end
      end
    end

    # Private.
    def recycle_workers
      reap_workers(Process::WNOHANG)
      raise 'todo: check for dead procs from master'
      while worker = @stopped_worker.shift
        worker.run
        @to_master_pipe.puts "+#{worker.pid},#{queues}"
        @running_workers[worker.pid] = worker
      end
    end

    # Private.
    def kill_all_workers(signal)
      @running_workers.values.each do |worker|
        worker.kill(signal)
      end
    end

    # Private.
    def wait_for_shutdown
      reap_workers
    end

    # Private.
    def yawn(duration)
      super(duration, [@from_master_pipe])
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
