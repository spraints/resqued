require 'resqorn/config'
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

    MIN_BACKOFF = 4.0
    MAX_BACKOFF = 64.0

    def start_listener
      if @listener_pid
        return
      end
      if @listener_started_at && @listener_backoff && Time.now - @listener_started_at < @listener_backoff
        @backoff = true
        return
      end
      @listener_started_at = Time.now
      @listener_backoff = @backoff ? [@listener_backoff * 2, MAX_BACKOFF].min : MIN_BACKOFF
      @backoff = false
      if @listener_pid = fork
        # master
        log "Started listener #{@listener_pid}"
      else
        uninstall_signal_handlers
        # Load the config in the listener process so that, if it does a 'require' or something, it only pollutes the listener.
        config = Config.load_file(@config_path)
        Listener.new(:config => config, :running_workers => @running_workers).run
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
        if status.exitstatus != 0
          log "Listener exited #{status}"
        end
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
          sleep 1
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
      SIGNALS.each { |signal| trap(signal) { SIGNAL_QUEUE << signal } }
    end

    def uninstall_signal_handlers
      SIGNALS.each { |signal| trap(signal, 'DEFAULT') }
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
