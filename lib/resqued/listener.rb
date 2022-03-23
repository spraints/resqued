require "socket"

require "resqued/config"
require "resqued/logging"
require "resqued/procline_version"
require "resqued/runtime_info"
require "resqued/sleepy"
require "resqued/version"
require "resqued/worker"

module Resqued
  # A listener process. Watches resque queues and forks workers.
  class Listener
    include Resqued::Logging
    include Resqued::ProclineVersion
    include Resqued::Sleepy

    # Configure a new listener object.
    #
    # Runs in the master process.
    def initialize(options)
      @config_paths    = options.fetch(:config_paths)
      @old_workers     = options.fetch(:old_workers) { [] }.freeze
      @socket          = options.fetch(:socket)
      @listener_id     = options.fetch(:listener_id) { nil }
    end

    # Public: As an alternative to #run, exec a new ruby instance for this listener.
    #
    # Runs in the master process.
    def exec
      socket_fd = @socket.to_i
      ENV["RESQUED_SOCKET"]      = socket_fd.to_s
      ENV["RESQUED_CONFIG_PATH"] = @config_paths.join(":")
      ENV["RESQUED_STATE"]       = @old_workers.map { |r| "#{r[:pid]}|#{r[:queue_key]}" }.join("||")
      ENV["RESQUED_LISTENER_ID"] = @listener_id.to_s
      ENV["RESQUED_MASTER_VERSION"] = Resqued::VERSION
      log "exec: #{Resqued::START_CTX['$0']} listener"
      exec_opts = { socket_fd => socket_fd } # Ruby 2.0 needs to be told to keep the file descriptor open during exec.
      if start_pwd = Resqued::START_CTX["pwd"]
        exec_opts[:chdir] = start_pwd
      end
      procline_buf = " " * 256 # make room for setproctitle
      Kernel.exec(Resqued::START_CTX["$0"], "listener", procline_buf, exec_opts)
    end

    # Public: Given args from #exec, start this listener.
    def self.exec!
      options = {}
      if socket = ENV["RESQUED_SOCKET"]
        options[:socket] = Socket.for_fd(socket.to_i)
      end
      if path = ENV["RESQUED_CONFIG_PATH"]
        options[:config_paths] = path.split(":")
      end
      if state = ENV["RESQUED_STATE"]
        options[:old_workers] = state.split("||").map { |s| Hash[[:pid, :queue_key].zip(s.split("|"))] }
      end
      if listener_id = ENV["RESQUED_LISTENER_ID"]
        options[:listener_id] = listener_id
      end
      new(options).run
    end

    SIGNALS = [:CONT, :QUIT, :INT, :TERM].freeze
    ALL_SIGNALS = SIGNALS + [:CHLD, :HUP]

    SIGNAL_QUEUE = [] # rubocop: disable Style/MutableConstant

    # Public: Run the main loop.
    def run
      trap(:HUP) {} # ignore this, in case it trickles in from the master.
      trap(:CHLD) { awake }
      SIGNALS.each { |signal| trap(signal) { SIGNAL_QUEUE << signal; awake } }
      @socket.close_on_exec = true
      write_procline("starting")

      config = Resqued::Config.new(@config_paths)
      set_default_resque_logger
      config.before_fork(info)
      report_to_master("RUNNING")

      write_procline("running")
      init_workers(config)
      exit_signal = run_workers_run

      write_procline("shutdown")
      burn_down_workers(exit_signal || :QUIT)
      @socket&.close
      @socket = nil
    end

    # Private.
    def set_default_resque_logger
      require "resque"
      if Resque.respond_to?("logger=")
        Resque.logger = Resqued::Logging.build_logger
      end
    rescue LoadError # rubocop: disable Lint/SuppressedException
      # Skip this step.
    end

    # Private.
    def run_workers_run
      loop do
        reap_workers(Process::WNOHANG)
        check_for_expired_workers
        start_idle_workers
        write_procline("running")
        case signal = SIGNAL_QUEUE.shift
        when nil
          yawn
        when :CONT
          kill_all(signal)
        when :QUIT, :INT, :TERM
          return signal
        end
      end
    end

    # Private: make sure all the workers stop.
    #
    # Resque workers have gaps in their signal-handling ability.
    def burn_down_workers(signal)
      loop do
        check_for_expired_workers
        write_procline("shutdown")
        SIGNAL_QUEUE.clear

        break if :no_child == reap_workers(Process::WNOHANG)

        kill_all(signal)

        sleep 1 # Don't kill any more often than every 1s.
        yawn 5
      end
      # One last time.
      reap_workers
    end

    # Private: send a signal to all the workers.
    def kill_all(signal)
      running = running_workers
      log "kill -#{signal} #{running.map { |r| r.pid }.inspect}"
      running.each { |worker| worker.kill(signal) }
    end

    # Private: all available workers
    attr_reader :workers

    # Private: just the running workers.
    def running_workers
      partition_workers.last
    end

    # Private: just the workers running as children of this listener.
    def my_workers
      workers.select { |worker| worker.running_here? }
    end

    # Private: Split the workers into [not-running, running]
    def partition_workers
      workers.partition { |worker| worker.idle? }
    end

    # Private.
    def yawn(sleep_time = nil)
      sleep_time ||=
        begin
          sleep_times = [60.0] + workers.map { |worker| worker.backing_off_for }
          [sleep_times.compact.min, 0.0].max
        end
      super(sleep_time, @socket)
    end

    # Private: Check for workers that have stopped running
    def reap_workers(waitpidflags = 0)
      loop do
        worker_pid, status = Process.waitpid2(-1, waitpidflags)
        return :none_ready if worker_pid.nil?

        log "Worker exited #{status}"
        finish_worker(worker_pid, status)
        report_to_master("-#{worker_pid}")
      end
    rescue Errno::ECHILD
      # All done
      :no_child
    end

    # Private: Check if master reports any dead workers.
    def check_for_expired_workers
      return unless @socket

      loop do
        IO.select([@socket], nil, nil, 0) or return
        line = @socket.readline
        finish_worker(line.to_i, nil)
      end
    rescue EOFError, Errno::ECONNRESET => e
      @socket = nil
      log "#{e.class.name} while reading from master"
      Process.kill(:QUIT, $$)
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
        next unless worker.idle?

        worker.try_start
        if pid = worker.pid
          report_to_master("+#{pid},#{worker.queue_key}")
        end
      end
    end

    # Private.
    def init_workers(config)
      @workers = config.build_workers
      @old_workers.each do |running_worker|
        if blocked_worker = @workers.detect { |worker| worker.idle? && worker.queue_key == running_worker[:queue_key] }
          blocked_worker.wait_for(running_worker[:pid].to_i)
        end
      end
    end

    # Private: Report child process status.
    #
    # Examples:
    #
    #     report_to_master("+12345,queue")  # Worker process PID:12345 started, working on a job from "queue".
    #     report_to_master("-12345")        # Worker process PID:12345 exited.
    def report_to_master(status)
      @socket&.puts(status)
    rescue Errno::EPIPE => e
      @socket = nil
      log "#{e.class.name} while writing to master"
      Process.kill(:QUIT, $$) # If the master is gone, LIFE IS NOW MEANINGLESS.
    end

    # Private.
    def write_procline(status)
      procline = "#{procline_version} listener"
      procline << " \##{@listener_id}" if @listener_id
      procline << " #{my_workers.size}/#{running_workers.size}/#{workers.size}" if workers
      procline << " [#{info.app_version}]" if info.app_version
      procline << " [#{status}]"
      procline << " #{@config_paths.join(' ')}"
      $0 = procline
    end

    # Private.
    def info
      @info ||= RuntimeInfo.new
    end
  end
end
