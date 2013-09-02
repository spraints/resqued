require 'resque'

require 'resqued/backoff'
require 'resqued/logging'

module Resqued
  # Models a worker process.
  class Worker
    include Resqued::Logging

    def initialize(options)
      @queues = options.fetch(:queues)
      @config = options.fetch(:config)
      @interval = options[:interval]
      @backoff = Backoff.new
    end

    # Public: The pid of the worker process.
    attr_reader :pid

    # Private.
    attr_reader :queues

    # Public: True if there is no worker process mapped to this object.
    def idle?
      pid.nil?
    end

    # Public: A string that compares if this worker is equivalent to a worker in another Resqued::Listener.
    def queue_key
      queues.sort.join(';')
    end

    # Public: Claim this worker for another listener's worker.
    def wait_for(pid)
      raise "Already running #{@pid} (can't wait for #{pid})" if @pid
      @self_started = false
      @pid = pid
    end

    # Public: The old worker process finished!
    def finished!(process_status)
      @pid = nil
      @backoff.died unless @killed
    end

    # Public: The amount of time we need to wait before starting a new worker.
    def backing_off_for
      @pid ? nil : @backoff.how_long?
    end

    # Public: Start a job, if there's one waiting in one of my queues.
    def try_start
      return if @backoff.wait?
      @backoff.started
      @self_started = true
      @killed = false
      if @pid = fork
        # still in the listener
      else
        # In case we get a signal before resque is ready for it.
        [:QUIT, :TERM, :INT].each { |signal| trap(signal) { exit 1 } }
        $0 = "STARTING RESQUE FOR #{queues.join(',')}"
        if Resque.respond_to?("logger")
          Resque.logger.level = Logger::INFO
          Resque.logger.formatter = Resque::VerboseFormatter.new
        end
        if ! log_to_stdout?
          lf = Resqued::Logging.logging_io
          if Resque.respond_to?("logger=")
            Resque.logger = Resque.logger.class.new(lf)
          else
            $stdout.reopen(lf)
            lf.close
          end
        end
        resque_worker = Resque::Worker.new(*queues)
        resque_worker.log "Starting worker #{resque_worker}"
        resque_worker.term_child = true
        resque_worker.reconnect
        @config.after_fork(resque_worker)
        resque_worker.work(@interval || 5)
        exit 0
      end
    end

    # Public: Shut this worker down.
    def kill(signal)
      Process.kill(signal.to_s, pid) if pid && @self_started
      @killed = true
    end
  end
end
