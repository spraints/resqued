require "fcntl"
require "socket"

require "resqued/listener"
require "resqued/logging"

module Resqued
  # Controls a listener process from the master process.
  class ListenerProxy
    include Resqued::Logging

    # Public.
    def initialize(state)
      @state = state
    end

    attr_reader :state

    # Public: wrap up all the things, this object is going home.
    def dispose
      if @state.master_socket
        @state.master_socket.close
        @state.master_socket = nil
      end
    end

    # Public: An IO to select on to check if there is incoming data available.
    def read_pipe
      @state.master_socket
    end

    # Public: The pid of the running listener process.
    def pid
      @state.pid
    end

    # Public: Start the listener process.
    def run
      return if pid

      listener_socket, master_socket = UNIXSocket.pair
      if @state.pid = fork
        # master
        listener_socket.close
        master_socket.close_on_exec = true
        log "Started listener #{@state.pid}"
        @state.master_socket = master_socket
      else
        # listener
        master_socket.close
        Master::TRAPS.each { |signal| trap(signal, "DEFAULT") rescue nil }
        Listener.new(@state.options.merge(socket: listener_socket)).exec
        exit
      end
    end

    # Public: Stop the listener process.
    def kill(signal)
      log "kill -#{signal} #{pid}"
      Process.kill(signal.to_s, pid)
    end

    # Public: Get the list of workers running from this listener.
    def running_workers
      worker_pids.map { |pid, queue_key| { pid: pid, queue_key: queue_key } }
    end

    # Private: Map worker pids to queue names
    def worker_pids
      @state.worker_pids ||= {}
    end

    # Public: Check for updates on running worker information.
    def read_worker_status(options)
      on_activity = options[:on_activity]
      until @state.master_socket.nil?
        IO.select([@state.master_socket], nil, nil, 0) or return
        case line = @state.master_socket.readline
        when /^\+(\d+),(.*)$/
          worker_pids[$1] = $2
          on_activity&.worker_started($1)
        when /^-(\d+)$/
          worker_pids.delete($1)
          on_activity&.worker_finished($1)
        when /^RUNNING/
          on_activity&.listener_running(self)
        when ""
          break
        else
          log "Malformed data from listener: #{line.inspect}"
        end
      end
    rescue EOFError, Errno::ECONNRESET
      @state.master_socket.close
      @state.master_socket = nil
    end

    # Public: Tell the listener process that a worker finished.
    def worker_finished(pid)
      return if @state.master_socket.nil?

      @state.master_socket.write_nonblock("#{pid}\n")
    rescue IO::WaitWritable
      log "Couldn't tell #{@state.pid} that #{pid} exited!"
      # Ignore it, maybe the next time it'll work.
    rescue Errno::EPIPE
      @state.master_socket.close
      @state.master_socket = nil
    end
  end
end
