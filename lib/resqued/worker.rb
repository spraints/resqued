require 'resque'

module ResqueDaemon
  # Wraps a Resque::Worker object with methods and attributes for managing the
  # spawned worker processes. This class handles forking off an individual
  # long-lived worker process as well as reaping its exit status.
  #
  # The ResqueDaemon::Master class is primarily responsible for creating and
  # maintaining Worker objects.
  class Worker
    # The worker number. This ranges from 1 to Master#worker_process.
    attr_reader   :number

    # The worker process's pid; nil when the process has not been spawned.
    attr_reader   :pid

    # The worker process's exit status as a Process::Status object. Only
    # available after the worker has been reaped.
    attr_reader   :status

    # Create a new Worker. The number is assigned by the Master. The queues and
    # options are passed to the Resque::Worker, which manages the child process
    # side of the process.
    def initialize(number, queues = [], options = {})
      @number = number
      @queues = queues
      @options = default_options.merge(options)
      @pid = nil
      @status = nil

      @worker = Resque::Worker.new(*queues)
      @worker.cant_fork = true
    end

    # Array of queue names this worker process will pull jobs from.
    def queues
      @worker.queues
    end

    # Has a pid been established? True only after the worker process has
    # been spawned.
    def pid?
      !@pid.nil?
    end

    # Has the worker process's exit status been collected? True only after the
    # process has exited and its status collected.
    def reaped?
      !@status.nil?
    end

    # Is the worker process thought to be running? This is not a guarantee that
    # the process is running. It only signifies that the process has previously
    # been started and its exit status has not yet been reaped.
    def running?
      pid? && !reaped?
    end

    # Fork off the worker process and record the new process's pid.
    def spawn
      fail "Attempt to spawn worker with assigned pid" if pid?
      @pid = fork { main }
    end

    # Called in the newly forked worker process, immediately after spawning.
    def main
      @worker.reconnect
      @worker.work
      exit!
    rescue Exception => boom
      exit! 1
    end

    # Attempt to collect a running worker process's exit status. Returns
    # immediately if the process has not yet been spawned or has already been
    # reaped.
    def reap
      if running? && Process::waitpid(pid, Process::WNOHANG)
        @status = $?
      end
    end

    # Default options passed when creating new Resque::Worker objects.
    def default_options
      {
        :timeout           => 5,      # for term
        :interval          => 5,      # poll interval
        :daemon            => false,  # we handle daemonization in the master
        :fork_per_job      => false,  # do not fork for each job run
        :run_at_exit_hooks => false   # don't run exit hooks
      }
    end
  end
end
