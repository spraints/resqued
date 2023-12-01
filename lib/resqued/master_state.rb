module Resqued
  # Tracks state from the master process. On re-exec, this object will
  # be serialized and passed to the new master.
  class MasterState
    def initialize
      @listeners_created = 0
      @listener_states = {}
    end

    # Public: When starting fresh, from command-line options, assign the
    # initial values.
    def init(options)
      @config_paths = options.fetch(:config_paths)
      @exec_on_hup  = options.fetch(:exec_on_hup, false)
      @fast_exit    = options.fetch(:fast_exit, false)
      @pidfile      = options.fetch(:master_pidfile, nil)
    end

    # Public: Restore state from a serialized form.
    def restore(data)
      @config_paths = data[:config_paths]
      @current_listener_pid = data[:current_listener_pid]
      @exec_on_hup = data[:exec_on_hup]
      @fast_exit = data[:fast_exit]
      @last_good_listener_pid = data[:last_good_listener_pid]
      @listeners_created = data[:listeners_created]
      data[:listener_states].each do |lsh|
        @listener_states[lsh[:pid]] = ListenerState.new.tap do |ls|
          ls.master_socket = lsh[:master_socket] && Socket.for_fd(lsh[:master_socket])
          ls.options = lsh[:options]
          ls.pid = lsh[:pid]
          ls.worker_pids = lsh[:worker_pids]
        end
      end
      @paused = data[:paused]
      @pidfile = data[:pidfile]
    end

    # Public: Return this state so that it can be serialized.
    def to_h
      {
        config_paths: @config_paths,
        current_listener_pid: @current_listener_pid,
        exec_on_hup: @exec_on_hup,
        fast_exit: @fast_exit,
        last_good_listener_pid: @last_good_listener_pid,
        listeners_created: @listeners_created,
        listener_states: @listener_states.values.map { |ls|
          {
            master_socket: ls.master_socket&.to_i,
            options: ls.options,
            pid: ls.pid,
            worker_pids: ls.worker_pids,
          }
        },
        paused: @paused,
        pidfile: @pidfile,
      }
    end

    # Public: Return an array of open sockets or other file handles that
    # should be forwarded to a new master.
    def sockets
      @listener_states.values.map { |l| l.master_socket }.compact
    end

    # Paths of app's resqued configuration files. The paths are passed
    # to the listener, and the listener reads the config so that it
    # knows which workers to create.
    attr_reader :config_paths

    # The PID of the newest listener. This is the one listener that
    # should continue running.
    attr_accessor :current_listener_pid

    # (Deprecated.) If true, on SIGHUP re-exec the master process before
    # starting a new listener.
    attr_reader :exec_on_hup

    # If true, on SIGTERM/SIGQUIT/SIGINT, don't wait for listeners to
    # exit before the master exits.
    attr_reader :fast_exit

    # The PID of the newest listener that booted successfully. This
    # listener won't be stopped until a newer listener boots
    # successfully.
    attr_accessor :last_good_listener_pid

    # The number of listeners that have been created by this master.
    attr_accessor :listeners_created

    # A hash of pid => ListenerState for all running listeners.
    attr_reader :listener_states

    # Set to true when this master is paused and should not be running
    # any listeners.
    attr_accessor :paused

    # If set, the master's PID will be written to this file.
    attr_reader :pidfile
  end
end
