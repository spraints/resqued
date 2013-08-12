require 'resque'

require 'resqued/backoff'

module Resqued
  # Models a worker process.
  class Worker
    def initialize(options)
      @queues = options.fetch(:queues)
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

    # Public: Checks if this worker works on jobs from the queue.
    def queue_key
      queues.sort.join(';')
    end

    # Public: Claim this worker for another listener's worker.
    def wait_for(pid)
      raise "Already running #{@pid} (can't wait for #{pid})" if @pid
      @self_started = nil
      @pid = pid
    end

    # Public: The old worker process finished!
    def finished!(process_status)
      @pid = nil
      @backoff.finished
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
      @pid = fork do
        $0 = "STARTING RESQUE FOR #{queues.join(',')}"
        resque_worker = Resque::Worker.new(*queues)
        resque_worker.term_child = true
        resque_worker.term_timeout = 999999999
        resque_worker.log "Starting worker #{resque_worker}"
        resque_worker.work(5)
      end
    end

    # Public: Shut this worker down.
    def kill(signal)
      signal = signal.to_s
      # Convert resqued semantics to resque's new semantics.
      signal =
        case signal
        when 'TERM' then 'INT'
        when 'QUIT' then 'TERM'
        else signal
        end
      Process.kill(signal, pid) if pid && @self_started
    end
  end
end
