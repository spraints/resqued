require 'fcntl'
require 'kgio'

require 'resqorn/listener_proxy'
require 'resqorn/logging'

module Resqorn
  # The master process.
  # * Spawns a listener.
  # * Tracks all work. (IO pipe from listener.)
  # * Handles signals.
  class Master
    include Resqorn::Logging

    def initialize(options)
      @config_path = options.fetch(:config_path)
      @pidfile     = options.fetch(:pidfile) { nil }
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
        start_listener
        read_listeners
        reap_all_listeners
        case signal = SIGNAL_QUEUE.shift
        when nil
          yawn(@backoff_remaining || 30.0)
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

    MIN_BACKOFF = 1.0
    MAX_BACKOFF = 64.0

    def all_listeners
      @all_listeners ||= {}
    end

    attr_reader :config_path
    attr_reader :pidfile

    def start_listener
      return if @current_listener

      if @listener_started_at && @listener_backoff && Time.now - @listener_started_at < @listener_backoff
        log "Waiting #{@listener_backoff}s before respawning..." if @backoff_remaining.nil?
        @backoff_remaining = @listener_backoff - (Time.now - @listener_started_at)
        return
      end

      @listener_started_at = Time.now
      @listener_backoff = @backoff_remaining.nil? ? MIN_BACKOFF : [@listener_backoff * 2, MAX_BACKOFF].min
      @backoff_remaining = nil

      @current_listener = ListenerProxy.new(:config_path => @config_path, :running_workers => all_listeners.map { |l| running_workers }.flatten)
      @current_listener.start
      @all_listeners[@current_listener.pid] = @current_listener
    end

    def read_listeners
      all_listeners.values.each { |l| l.read_worker_status }
    end

    def kill_listener(signal)
      if @current_listener
        @current_listener.kill(signal)
        @current_listener = nil
      end
    end

    def kill_all_listeners(signal)
      all_listeners.values.each do |l|
        l.kill(signal)
      end
    end

    def wait_for_workers
      while all_listeners.any?
        reap_all_listeners
        yawn(30.0)
      end
    end

    def reap_all_listeners
      begin
        lpid, status = Process.waitpid2(-1, Process::WNOHANG)
        if lpid
          log "Listener exited #{status}"
          @current_listener = nil if @current_listener.pid == lpid
          all_listeners.delete(lpid)
        else
          return
        end
      rescue Errno::ECHILD
        return
      end while true
    end

    SIGNALS = [ :HUP, :INT, :TERM, :QUIT, :CHLD ]

    SIGNAL_QUEUE = []

    def install_signal_handlers
      SIGNALS.each { |signal| trap(signal) { SIGNAL_QUEUE << signal ; awake } }
    end

    def uninstall_signal_handlers
      SIGNALS.each { |signal| trap(signal, 'DEFAULT') }
    end

    def self_pipe
      @self_pipe ||= Kgio::Pipe.new.each { |io| io.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC) }
    end


    def yawn(duration)
      inputs = [ self_pipe[0] ] + all_listeners.map { |l| l.read_pipe }
      IO.select(inputs, nil, nil, duration) or return
      self_pipe[0].kgio_tryread(11)
    end

    def awake
      self_pipe[1].kgio_trywrite('.')
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
