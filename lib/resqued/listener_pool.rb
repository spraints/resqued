require "resqued/listener_proxy"
require "resqued/listener_state"

module Resqued
  class ListenerPool
    include Enumerable

    # Public: Initialize a new pool, and store state in the given master's state.
    def initialize(master_state)
      @master_state = master_state
      @listener_proxies = {}
      # If this master is replacing an old one, there will be listeners in the state already.
      @master_state.listener_states.each do |pid, ls|
        @listener_proxies[pid] = ListenerProxy.new(ls)
      end
    end

    # Public: Iterate through all active ListenerProxy instances.
    def each(&block)
      @listener_proxies.values.each(&block)
    end

    # Public: Number of active listeners.
    def size
      @listener_proxies.size
    end

    # Public: Are the listeners all gone?
    def empty?
      @listener_proxies.empty?
    end

    # Public: Initialize a new listener, run it, and record it as the current listener. Returns its ListenerProxy.
    def start!
      listener_state = ListenerState.new
      listener_state.options = {
        config_paths: @master_state.config_paths,
        old_workers: map { |l| l.running_workers }.flatten,
        listener_id: next_listener_id,
      }
      listener = ListenerProxy.new(listener_state)
      listener.run
      @master_state.listener_states[listener.pid] = listener_state
      @listener_proxies[listener.pid] = listener
      @master_state.current_listener_pid = listener.pid
      return listener
    end

    # Public: Remove the given pid from the set of known listeners, and return its ListenerProxy.
    def delete(pid)
      @master_state.listener_states.delete(pid)
      return @listener_proxies.delete(pid)
    end

    # Public: The current ListenerProxy, if available.
    def current
      @listener_proxies[current_pid]
    end

    # Public: The pid of the current listener, if available.
    def current_pid
      @master_state.current_listener_pid
    end

    # Public: Don't consider the current listener to be current anymore.
    def clear_current!
      @master_state.current_listener_pid = nil
    end

    # Public: Change the current listener into the last good listener.
    def cycle_current
      @master_state.last_good_listener_pid = @master_state.current_listener_pid
      @master_state.current_listener_pid = nil
    end

    # Public: The last good (previous current) ListenerProxy, if available.
    def last_good
      @listener_proxies[last_good_pid]
    end

    # Public: The pid of the last good listener, if available.
    def last_good_pid
      @master_state.last_good_listener_pid
    end

    # Public: Forget which listener was the last good one.
    def clear_last_good!
      @master_state.last_good_listener_pid = nil
    end

    private

    def next_listener_id
      @master_state.listeners_created += 1
    end
  end
end
