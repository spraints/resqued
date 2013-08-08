module Resqorn
  # Models a worker process.
  class Worker
    def initialize(options)
      @queues = options.fetch(:queues)
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
    end

    # Public: Start a job, if there's one waiting in one of my queues.
    def try_start
      @self_started = true
      @pid = fork do
        # todo! start resque worker!
      end
    end

    # Public: Shut this worker down.
    def kill(signal)
      Process.kill(signal.to_s, pid) if pid && @self_started
    end
  end
end
