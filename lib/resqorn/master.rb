require 'resqorn/backoff'
require 'resqorn/listener_proxy'
require 'resqorn/logging'
require 'resqorn/sleepy'

module Resqorn
  # The master process.
  # * Spawns a listener.
  # * Tracks all work. (IO pipe from listener.)
  # * Handles signals.
  class Master
    include Resqorn::Logging
    include Resqorn::Sleepy

    def initialize(options)
      @config_path = options.fetch(:config_path)
      @pidfile     = options.fetch(:pidfile) { nil }
      @listener_backoff = Backoff.new
    end

    # Public: Starts the master process.
    def run
      write_pid
      write_procline
      install_signal_handlers
      go_ham
    end

    # Private: dat main loop.
    def go_ham
      loop do
        read_listeners
        reap_all_listeners
        start_listener
        case signal = SIGNAL_QUEUE.shift
        when nil
          yawn(@listener_backoff.how_long? || 30.0)
        when :HUP
          log "Restarting listener with new configuration and application."
          kill_listener(:QUIT)
        when :INT, :TERM
          log "Shutting down now."
          kill_all_listeners(signal)
          break
        when :QUIT
          log "Shutting down when work is finished."
          kill_all_listeners(signal)
          wait_for_workers
          break
        end
      end
    end

    # Private: Map listener pids to ListenerProxy objects.
    def listener_pids
      @listener_pids ||= {}
    end

    # Private: All the ListenerProxy objects.
    def all_listeners
      listener_pids.values
    end

    attr_reader :config_path
    attr_reader :pidfile

    def start_listener
      return if @current_listener || @listener_backoff.wait?
      @current_listener = ListenerProxy.new(:config_path => @config_path, :running_workers => all_listeners.map { |l| l.running_workers }.flatten)
      @current_listener.run
      @listener_backoff.started
      listener_pids[@current_listener.pid] = @current_listener
    end

    def read_listeners
      all_listeners.each do |l|
        l.read_worker_status(:on_finished => lambda { |pid| all_listeners.each { |other| other.worker_finished(pid) } })
      end
    end

    def kill_listener(signal)
      if @current_listener
        @current_listener.kill(signal)
        @current_listener = nil
      end
    end

    def kill_all_listeners(signal)
      all_listeners.each do |l|
        l.kill(signal)
      end
    end

    def wait_for_workers
      while listener_pids.any?
        reap_all_listeners
        yawn(30.0)
      end
    end

    def reap_all_listeners
      begin
        lpid, status = Process.waitpid2(-1, Process::WNOHANG)
        if lpid
          log "Listener exited #{status}"
          if @current_listener && @current_listener.pid == lpid
            @listener_backoff.finished
            @current_listener = nil
          end
          listener_pids.delete(lpid) # This may leak workers.
        else
          return
        end
      rescue Errno::ECHILD
        return
      end while true
    end

    SIGNALS = [ :HUP, :INT, :TERM, :QUIT ]

    SIGNAL_QUEUE = []

    def install_signal_handlers
      trap(:CHLD) { awake }
      SIGNALS.each { |signal| trap(signal) { SIGNAL_QUEUE << signal ; awake } }
    end


    def yawn(duration)
      super(duration, all_listeners.map { |l| l.read_pipe })
    end

    def write_pid
      if @pidfile
        if File.exists?(@pidfile)
          raise "#{@pidfile} already exists!"
        end
        File.open(@pidfile, File::RDWR|File::CREAT|File::EXCL, 0644) do |f|
          f.syswrite("#{$$}\n")
        end
      end
    end

    def write_procline
      $0 = "resqorn master #{ARGV.join(' ')}"
    end
  end
end
