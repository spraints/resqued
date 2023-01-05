require "digest"

require "resqued/backoff"
require "resqued/logging"

module Resqued
  # Models a worker process.
  class Worker
    include Resqued::Logging

    DEFAULT_WORKER_FACTORY = lambda { |queues|
      require "resque"
      resque_worker = Resque::Worker.new(*queues)
      resque_worker.term_child = true if resque_worker.respond_to?("term_child=")
      redis_client = Resque.redis.respond_to?(:_client) ? Resque.redis._client : Resque.redis.client
      if redis_client.respond_to?(:reconnect)
        redis_client.reconnect
      else
        redis_client.close
      end
      resque_worker
    }

    def initialize(options)
      @queues = options.fetch(:queues)
      @config = options.fetch(:config)
      @interval = options[:interval]
      @backoff = Backoff.new
      @worker_factory = options.fetch(:worker_factory, DEFAULT_WORKER_FACTORY)
      @pids = []
    end

    # Public: The pid of the worker process.
    attr_reader :pid

    # Private.
    attr_reader :queues

    # Public: True if there is no worker process mapped to this object.
    def idle?
      pid.nil?
    end

    # Public: True if this worker is running in this process.
    def running_here?
      !idle? && @self_started
    end

    # Public: A string that compares if this worker is equivalent to a worker in another Resqued::Listener.
    def queue_key
      Digest::SHA256.hexdigest(queues.sort.join(";"))
    end

    # Public: Claim this worker for another listener's worker.
    def wait_for(pid)
      raise "Already running #{@pid} (can't wait for #{pid})" if @pid

      @self_started = false
      @pids << pid
      @pid = pid
    end

    # Public: The old worker process finished!
    def finished!(process_status)
      summary = "(#{@pid}/#{@pids.inspect}/self_started=#{@self_started}/killed=#{@killed})"
      if process_status.nil? && !@self_started
        log :debug, "#{summary} I am no longer blocked."
        @pid = nil
        @backoff.died unless @killed
      elsif !process_status.nil? && @self_started
        alive_time_sec = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @start_time
        @config.after_exit(WorkerSummary.new(alive_time_sec: alive_time_sec, process_status: process_status))

        log :debug, "#{summary} I exited: #{process_status}"
        @pid = nil
        @backoff.died unless @killed
      else
        log :debug, "#{summary} Reports of my death are highly exaggerated (#{process_status.inspect})"
      end
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
      @start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      if @pid = fork
        @pids << @pid
        # still in the listener
        log "Forked worker #{@pid}"
      else
        # In case we get a signal before resque is ready for it.
        Resqued::Listener::ALL_SIGNALS.each { |signal| trap(signal, "DEFAULT") }
        # Continue ignoring SIGHUP, though.
        trap(:HUP) {}
        # If we get a QUIT during boot, just spin back down.
        trap(:QUIT) { exit! 0 }

        $0 = "STARTING RESQUE FOR #{queues.join(',')}"
        resque_worker = @worker_factory.call(queues)
        @config.after_fork(resque_worker)
        resque_worker.work(@interval || 5)
        exit 0
      end
    end

    # Public: Shut this worker down.
    def kill(signal)
      Process.kill(signal.to_s, pid) if pid && @self_started
      @killed = true
    rescue Errno::ESRCH => e
      log "Can't kill #{pid}: #{e}"
    end
  end

  # Metadata for an exited listener worker.
  class WorkerSummary
    attr_reader :alive_time_sec, :process_status

    def initialize(alive_time_sec:, process_status:)
      @alive_time_sec = alive_time_sec
      @process_status = process_status
    end
  end
end
