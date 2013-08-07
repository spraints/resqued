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
    def watches_queue?(queue)
      queues.include?(queue)
    end

    # Public: Claim this worker for another listener's worker.
    def wait_for(pid)
      @pid = pid.to_i
    end

    # Public: The worker process finished!
    def finished!(process_status)
      @pid = nil
    end

    # Public: Start a job, if there's one waiting in one of my queues.
    def try_start
    end
  end
end
