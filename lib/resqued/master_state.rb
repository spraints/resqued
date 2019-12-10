module Resqued
  class MasterState
    def initialize
      @listeners_created = 0
      @listener_states = {}
    end

    # Public: When starting fresh, from command-line options, assign the initial values.
    def init(options)
      @config_paths = options.fetch(:config_paths)
      @exec_on_hup  = options.fetch(:exec_on_hup) { false }
      @fast_exit    = options.fetch(:fast_exit) { false }
      @pidfile      = options.fetch(:master_pidfile) { nil }
    end

    # Public: Restore state from a serialized form.
    def restore(h)
      @config_paths = h[:config_paths]
      @current_listener_pid = h[:current_listener_pid]
      @exec_on_hup = h[:exec_on_hup]
      @fast_exit = h[:fast_exit]
      @last_good_listener_pid = h[:last_good_listener_pid]
      @listeners_created = h[:listeners_created]
      h[:listener_states].each do |lsh|
        @listener_states[lsh[:pid]] = ListenerState.new.tap do |ls|
          ls.master_socket = lsh[:master_socket] && Socket.for_fd(lsh[:master_socket])
          ls.options = lsh[:options]
          ls.pid = lsh[:pid]
          ls.worker_pids = lsh[:worker_pids]
        end
      end
      @paused = h[:paused]
      @pidfile = h[:pidfile]
    end

    # Public: Return this state so that it can be serialized.
    def to_h
      {
        :config_paths => @config_paths,
        :current_listener_pid => @current_listener_pid,
        :exec_on_hup => @exec_on_hup,
        :fast_exit => @fast_exit,
        :last_good_listener_pid => @last_good_listener_pid,
        :listeners_created => @listeners_created,
        :listener_states => @listener_states.values.map { |ls| {
          :master_socket => ls.master_socket && ls.master_socket.to_i,
          :options => ls.options,
          :pid => ls.pid,
          :worker_pids => ls.worker_pids,
        } },
        :paused => @paused,
        :pidfile => @pidfile,
      }
    end

    # Public: Return an array of open sockets or other file handles that should be forwarded to a new master.
    def sockets
      @listener_states.values.map { |l| l.master_socket }.compact
    end

    attr_reader :config_paths
    attr_accessor :current_listener_pid
    attr_reader :exec_on_hup
    attr_reader :fast_exit
    attr_accessor :last_good_listener_pid
    attr_accessor :listeners_created
    attr_reader :listener_states
    attr_accessor :paused
    attr_reader :pidfile
  end
end
