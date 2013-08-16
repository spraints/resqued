require 'fcntl'
require 'socket'

require 'resqued/listener'
require 'resqued/logging'

module Resqued
  class ListenerProxy
    include Resqued::Logging

    # Public.
    def initialize(options)
      @options = options
    end

    # Public: wrap up all the things, this object is going home.
    def dispose
      if @master_socket
        @master_socket.close
        @master_socket = nil
      end
    end

    # Public: An IO to select on to check if there is incoming data available.
    def read_pipe
      @master_socket
    end

    # Public: The pid of the running listener process.
    attr_reader :pid

    # Public: Start the listener process.
    def run
      return if pid
      listener_socket, master_socket = UNIXSocket.pair
      if @pid = fork
        # master
        listener_socket.close
        master_socket.close_on_exec = true
        log "Started listener #{@pid}"
        @master_socket = master_socket
      else
        # listener
        master_socket.close
        Master::SIGNALS.each { |signal| trap(signal, 'DEFAULT') }
        Listener.new(@options.merge(:socket => listener_socket)).exec
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
      worker_pids.map { |pid, queue| { :pid => pid, :queue => queue } }
    end

    # Private: Map worker pids to queue names
    def worker_pids
      @worker_pids ||= {}
    end

    # Public: Check for updates on running worker information.
    def read_worker_status(options)
      return if @master_socket.nil?
      on_finished = options[:on_finished]
      loop do
        IO.select([@master_socket], nil, nil, 0) or return
        line = @master_socket.readline
        if line =~ /^\+(\d+),(.*)$/
          worker_pids[$1] = $2
        elsif line =~ /^-(\d+)$/
          worker_pids.delete($1)
          on_finished.worker_finished($1) if on_finished
        elsif line == ''
          break
        else
          log "Malformed data from listener: #{line.inspect}"
        end
      end
    rescue EOFError
      @master_socket.close
      @master_socket = nil
    end

    # Public: Report that a worker finished.
    def worker_finished(pid)
      return if @master_socket.nil?
      @master_socket.puts(pid)
    end
  end
end
