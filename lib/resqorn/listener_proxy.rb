require 'fcntl'

require 'resqorn/listener'
require 'resqorn/logging'

module Resqorn
  class ListenerProxy
    include Resqorn::Logging

    # Public.
    def initialize(options)
      @options = options
    end

    # Public: An IO to select on to check if there is incoming data available.
    def read_pipe
      @from_listener_pipe
    end

    # Public: The pid of the running listener process.
    attr_reader :pid

    # Public: Start the listener process.
    def run
      return if pid
      @from_listener_pipe, @to_master_pipe = IO.pipe
      @from_master_pipe, @to_listener_pipe = IO.pipe
      listener_pipes = [@to_master_pipe,   @from_master_pipe]
      master_pipes   = [@to_listener_pipe, @from_listener_pipe]
      if @pid = fork
        # master
        log "Started listener #{@pid}"
        listener_pipes.each { |p| p.close }
        master_pipes.each { |p| p.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC) }
      else
        # listener
        Master::SIGNALS.each { |signal| trap(signal, 'DEFAULT') }
        master_pipes.each { |p| p.close }
        listener_pipes.each { |p| p.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC) }
        Listener.new(@options.merge(:to_master => @to_master_pipe, :from_master => @from_master_pipe)).run
        exit
      end
    end

    # Public: Stop the listener process.
    def kill(signal)
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
      on_finished = options.fetch(:on_finished) { lambda { |pid| } }
      loop do
        IO.select([@from_listener_pipe], nil, nil, 0) or return
        line = @from_listener_pipe.readline
        if line =~ /^\+(\d+),(.*)\n/
          worker_pids[$1] = $2
        elsif line =~ /^-(\d+)\n/
          worker_pids.delete($1)
          on_finished.call($1)
        else
          log "Malformed data from listener: #{line.inspect}"
        end
      end
    rescue EOFError
    end

    # Public: Report that a worker finished.
    def worker_finished(pid)
      @to_listener_pipe.puts(pid) if @to_listener_pipe
    rescue EOFError, Errno::EPIPE
      @to_listener_pipe = nil
    end
  end
end
