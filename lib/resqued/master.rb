require 'resqued/worker'

module ResqueDaemon
  class Master
    # List of queue definitions
    attr_reader :queues

    # Number of worker child processes to spawn.
    attr_accessor :worker_processes

    # Additional options passed to all worker objects created.
    # See Resque::Worker for a list of supported options and values.
    attr_reader :options

    # Access the ResqueDaemon::Worker objects we're managing.
    attr_reader :workers

    def initialize(queues = {'*' => 1.0}, options = {})
      @queues = queues
      @options = options.dup
      options.keys.each { |k| respond_to?("#{k}=") && send("#{k}=", @options.delete(k)) }

      @worker_processes ||= 1
      @workers = []

      @shutdown = nil
      @shutdown_time = nil
    end

    # The main run loop. Maintains the worker pool.
    def run
      install_signal_handlers
      while true
        begin
          process_signals
          reap_workers
          build_workers
          spawn_workers
          sleep 0.100
        rescue Exception => boom
          logger.error "ERROR IN MASTER RUN LOOP: #{boom.class} #{boom.to_s}"
          logger.debug boom.backtrace.join("\n")
          shutdown('TERM')
        end
        break if !workers.any? { |w| w.running? }
      end
    ensure
      uninstall_signal_handlers
    end

    # Initiate shutdown for the master and all worker processes. The method
    # returns immediately. The #run method will exit after all worker processes
    # have been cleaned up.
    def shutdown(signal = 'TERM')
      logger.info "master received #{signal}, initiating shutdown"
      @shutdown = signal
      @shutdown_time = nil
    end

    # Internal: Build an array of Worker objects with queue lists configured based
    # on the concurrency values established and the total number of workers. No
    # worker processes are spawned from this method. The #workers array is
    # guaranteed to be the size of the configured worker process count and there
    # is a Worker object in each slot.
    #
    # Returns nothing.
    def build_workers
      return if @shutdown
      queues = fixed_concurrency_queues
      worker_processes.times do |slot|
        worker = workers[slot]
        if worker.nil? || worker.reaped?
          worker_num = slot + 1
          queue_names = queues.
            select { |name, concurrency| concurrency >= worker_num }.
            map    { |name, _| name }
          if queue_names.empty?
            workers.pop while workers.size >= worker_num
          else
            worker = ResqueDaemon::Worker.new(worker_num, queue_names, options)
            workers[slot] = worker
          end
        end
      end
    end

    # Internal: Fork off any unspawned worker processes. Ignore worker processes
    # that have already been spawned, even if their process isn't running
    # anymore.
    def spawn_workers
      return if @shutdown
      workers.each do |worker|
        next if worker.pid?
        logger.debug "master spawning worker #{worker.number}"
        worker.spawn { uninstall_signal_handlers }
      end
    end

    # Internal: Attempt to reap process exit codes from all workers that have
    # exited. Ignore workers that haven't been spawned yet or have already been
    # reaped.
    def reap_workers
      workers.each do |worker|
        if !worker.running?
          next
        elsif status = worker.reap
          logger.debug "master reaped worker #{worker.number} (pid=#{worker.pid}, status=#{status.exitstatus})"
        end
      end
    end

    # Internal: Like #queues but with concrete fixed concurrency values. All
    # percentage based concurrency values are converted to fixnum total number
    # of workers that queue should run on.
    def fixed_concurrency_queues
      queues.map { |name, concurrency| [name, translate_concurrency_value(concurrency)] }
    end

    # Internal: Convert a queue worker concurrency value to a fixed number of
    # workers. This supports values that are fixed numbers as well as percentage
    # values (between 0.0 and 1.0). The value may also be nil, in which case the
    # maximum worker_processes value is returned.
    def translate_concurrency_value(value)
      case
      when value.nil?
        worker_processes
      when value.is_a?(Fixnum)
        value < worker_processes ? value : worker_processes
      when value.is_a?(Float) && value >= 0.0 && value <= 1.0
        (worker_processes * value).to_i
      else
        raise TypeError, "Unknown concurrency value: #{value.inspect}"
      end
    end

    # Internal: Send a signal to all running working processes.
    def kill_workers(signal)
      running = workers.select { |w| w.running? }
      logger.debug "master sending SIG#{signal} to #{running.size} workers"
      running.each { |worker| worker.kill(signal) }
    end

    # Internal: Process any pending signal states. If the @shutdown flag is set
    # but the workers have not yet been signaled, do that now.
    def process_signals
      return if @shutdown.nil?

      if @shutdown_time.nil?
        @shutdown_time = Time.now
        kill_workers(@shutdown)
      end
    end

    # Internal: Install signal handler traps for managing the worker pool.
    def install_signal_handlers
      %w[INT TERM QUIT].each do |signal|
        trap(signal) { shutdown(signal) }
      end
      trap('HUP')  { @reload = true }
      trap('USR1') { @reopen = true }
      trap('USR2') { @reexec = true }
    end

    # Internal: Reset all signal handlers back to their defaults.
    def uninstall_signal_handlers
      %w[INT TERM QUIT HUP USR1 USR2].each do |signal|
        trap(signal, 'DEFAULT')
      end
    end

    def logger
      Resque.logger
    end
  end
end
