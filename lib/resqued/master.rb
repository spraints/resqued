require 'resqued/backoff'
require 'resqued/listener_proxy'
require 'resqued/logging'
require 'resqued/sleepy'

module Resqued
  # The master process.
  # * Spawns a listener.
  # * Tracks all work. (IO pipe from listener.)
  # * Handles signals.
  class Master
    include Resqued::Logging
    include Resqued::Sleepy

    def initialize(options)
      @config_path = options.fetch(:config_path)
      @pidfile     = options.fetch(:pidfile) { nil }
      @listener_backoff = Backoff.new
    end

    # Public: Starts the master process.
    def run(ready_pipe = nil)
      write_pid
      write_procline
      install_signal_handlers
      if ready_pipe
        ready_pipe.syswrite($$.to_s)
        ready_pipe.close rescue nil
      end
      go_ham
    end

    # Private: dat main loop.
    def go_ham
      loop do
        read_listeners
        reap_all_listeners(Process::WNOHANG)
        start_listener
        case signal = SIGNAL_QUEUE.shift
        when nil
          yawn(@listener_backoff.how_long? || 30.0)
        when :HUP
          log "Restarting listener with new configuration and application."
          kill_listener(:QUIT)
        when :INT, :TERM, :QUIT
          log "Shutting down..."
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
      reap_all_listeners
    end

    def reap_all_listeners(waitpid_flags = 0)
      begin
        lpid, status = Process.waitpid2(-1, waitpid_flags)
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
      $0 = "resqued master #{ARGV.join(' ')}"
    end
  end
end
