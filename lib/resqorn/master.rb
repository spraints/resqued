require 'kgio'

require 'resqorn/listener'

module Resqorn
  # The master process.
  # * Spawns a listener.
  # * Tracks all work. (IO pipe from listener.)
  # * Handles signals.
  class Master
    def initialize(options)
      @config_path = options.fetch(:config_path)
      @pidfile     = options.fetch(:pidfile) { nil }
      @running_workers = []
    end

    # Public: Starts the master process.
    def run
      write_pid
      write_procline
      install_signal_handlers
      start_listener
      handle_signals
    end

    MIN_BACKOFF = 1.0
    MAX_BACKOFF = 64.0

    def start_listener
      if @listener_pid
        return
      end
      if @listener_started_at && @listener_backoff && Time.now - @listener_started_at < @listener_backoff
        log "Waiting #{@listener_backoff}s before respawning..." if @backoff_remaining.nil?
        @backoff_remaining = @listener_backoff - (Time.now - @listener_started_at)
        return
      end
      @listener_started_at = Time.now
      @listener_backoff = @backoff_remaining.nil? ? MIN_BACKOFF : [@listener_backoff * 2, MAX_BACKOFF].min
      @backoff_remaining = nil
      if @listener_pid = fork
        # master
        log "Started listener #{@listener_pid}"
      else
        uninstall_signal_handlers
        # Load the config in the listener process so that, if it does a 'require' or something, it only pollutes the listener.
        Listener.new(:config_path => @config_path, :running_workers => @running_workers).run
        exit
      end
    end

    def kill_listener(signal)
      if @listener_pid
        log "Killing listener #{@listener_pid} with #{signal}"
        Process.kill(signal.to_s, @listener_pid)
        wait_listener
      end
    end

    def wait_listener
      if @listener_pid
        pid, status = Process.waitpid2(@listener_pid)
        log "Listener exited #{status}"
        @listener_pid = nil
      end
    end

    SIGNALS = [ :HUP, :INT, :TERM, :QUIT, :CHLD ]

    SIGNAL_QUEUE = []

    def handle_signals
      loop do
        start_listener
        case signal = SIGNAL_QUEUE.shift
        when nil
          yawn(@backoff_remaining || 30.0)
        when :CHLD
          log "Child died!"
          wait_listener
        when :HUP
          log "Reloading configuration and application."
          kill_listener(:QUIT)
        when :INT, :TERM
          log "Shutting down now."
          #kill_workers(signal)
          kill_listener(signal)
          break
        when :QUIT
          log "Shutting down when work is finished."
          kill_listener(signal)
          #wait_for_workers
          break
        end
      end
    end

    def install_signal_handlers
      SIGNALS.each { |signal| trap(signal) { SIGNAL_QUEUE << signal ; awake } }
    end

    def uninstall_signal_handlers
      SIGNALS.each { |signal| trap(signal, 'DEFAULT') }
    end

    def self_pipe
      @self_pipe ||= Kgio::Pipe.new
    end

    def yawn(duration)
      IO.select([ self_pipe[0] ], nil, nil, duration) or return
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

    def log(message)
      puts "[#{$$} #{Time.now.strftime('%H:%M:%D')}] #{message}"
    end
  end
end
