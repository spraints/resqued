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
      @worker_class = options.fetch(:worker_class, Resque::Worker)
      @interval = options[:interval]
      @backoff = Backoff.new
      @pids = []
    end

    # Public: The pid of the worker process.
    attr_reader :pid

    # Private.
    attr_reader :queues

    attr_reader :worker_class

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
      queues.sort.join(';')
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
      if process_status.nil? && ! @self_started
        log :debug, "(#{@pid}/#{@pids.inspect}/self_started=#{@self_started}/killed=#{@killed}) I am no longer blocked."
        @pid = nil
        @backoff.died unless @killed
      elsif ! process_status.nil? && @self_started
        log :debug, "(#{@pid}/#{@pids.inspect}/self_started=#{@self_started}/killed=#{@killed}) I exited: #{process_status}"
        @pid = nil
        @backoff.died unless @killed
      else
        log :debug, "(#{@pid}/#{@pids.inspect}/self_started=#{@self_started}/killed=#{@killed}) Reports of my death are highly exaggerated (#{process_status.inspect})"
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
      if @pid = fork
        @pids << @pid
        # still in the listener
        log "Forked worker #{@pid}"
      else
        # In case we get a signal before resque is ready for it.
        Resqued::Listener::ALL_SIGNALS.each { |signal| trap(signal, 'DEFAULT') }
        trap(:QUIT) { exit! 0 } # If we get a QUIT during boot, just spin back down.
        $0 = "STARTING RESQUE FOR #{queues.join(',')}"
        resque_worker = worker_class.new(*queues)
        resque_worker.term_child = true if resque_worker.respond_to?('term_child=')
        Resque.redis.client.reconnect
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
end
