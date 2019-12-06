module Resqued
  class MasterState
    def initialize(options)
      @config_paths = options.fetch(:config_paths)
      @fast_exit    = options.fetch(:fast_exit) { false }
      @pidfile      = options.fetch(:master_pidfile) { nil }
      @listeners_created = 0
    end

    attr_reader :config_paths
    attr_accessor :current_listener
    attr_reader :fast_exit
    attr_accessor :last_good_listener
    attr_accessor :listeners_created
    attr_accessor :listener_pids
    attr_accessor :paused
    attr_reader :pidfile
  end
end
