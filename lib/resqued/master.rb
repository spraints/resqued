require "resqued/backoff"
require "resqued/listener_pool"
require "resqued/logging"
require "resqued/master_state"
require "resqued/pidfile"
require "resqued/procline_version"
require "resqued/replace_master"
require "resqued/sleepy"

module Resqued
  # The master process.
  # * Spawns a listener.
  # * Tracks all work. (IO pipe from listener.)
  # * Handles signals.
  class Master
    include Resqued::Logging
    include Resqued::Pidfile
    include Resqued::ProclineVersion
    include Resqued::Sleepy

    def initialize(state, options = {})
      @state = state
      @status_pipe = options.fetch(:status_pipe, nil)
      @listeners = ListenerPool.new(state)
      @listener_backoff = Backoff.new
    end

    # Public: Starts the master process.
    def run(ready_pipe = nil)
      report_unexpected_exits
      with_pidfile(@state.pidfile) do
        write_procline
        install_signal_handlers
        if ready_pipe
          ready_pipe.syswrite($$.to_s)
          ready_pipe.close rescue nil
        end
        go_ham
      end
      no_more_unexpected_exits
    end

    # Private: dat main loop.
    def go_ham
      # If we're resuming, we'll want to recycle the existing listener now.
      prepare_new_listener

      loop do
        read_listeners
        reap_all_listeners(Process::WNOHANG)
        start_listener unless @state.paused
        case signal = SIGNAL_QUEUE.shift
        when nil
          yawn(@listener_backoff.how_long? || 30.0)
        when :INFO
          dump_object_counts
        when :HUP
          reopen_logs
          log "Restarting listener with new configuration and application."
          prepare_new_listener
        when :USR1
          log "Execing a new master"
          ReplaceMaster.exec!(@state)
        when :USR2
          log "Pause job processing"
          @state.paused = true
          kill_listener(:QUIT, @listeners.current)
          @listeners.clear_current!
        when :CONT
          log "Resume job processing"
          @state.paused = false
          kill_all_listeners(:CONT)
        when :INT, :TERM, :QUIT
          log "Shutting down..."
          kill_all_listeners(signal)
          wait_for_workers unless @state.fast_exit
          break
        end
      end
    end

    # Private.
    def dump_object_counts
      log GC.stat.inspect
      counts = {}
      total = 0
      ObjectSpace.each_object do |o|
        count = counts[o.class.name] || 0
        counts[o.class.name] = count + 1
        total += 1
      end
      top = 10
      log "#{total} objects. top #{top}:"
      counts.sort_by { |_, count| -count }.each_with_index do |(name, count), i|
        next unless i < top

        diff = ""
        if last = @last_counts && @last_counts[name]
          diff = sprintf(" (%+d)", (count - last))
        end
        log "   #{count} #{name}#{diff}"
      end
      @last_counts = counts
      log GC.stat.inspect
    rescue => e
      log "Error while counting objects: #{e}"
    end

    def start_listener
      return if @listeners.current || @listener_backoff.wait?

      listener = @listeners.start!
      listener_status listener, "start"
      @listener_backoff.started
      write_procline
    end

    def read_listeners
      @listeners.each do |l|
        l.read_worker_status(on_activity: self)
      end
    end

    # Listener message: A worker just started working.
    def worker_started(pid)
      worker_status(pid, "start")
    end

    # Listener message: A worker just stopped working.
    #
    # Forwards the message to the other listeners.
    def worker_finished(pid)
      worker_status(pid, "stop")
      @listeners.each do |other|
        other.worker_finished(pid)
      end
    end

    # Listener message: A listener finished booting, and is ready to
    # start workers.
    #
    # Promotes a booting listener to be the current listener.
    def listener_running(listener)
      listener_status(listener, "ready")
      if listener == @listeners.current
        kill_listener(:QUIT, @listeners.last_good)
        @listeners.clear_last_good!
      else
        # This listener didn't receive the last SIGQUIT we sent.
        # (It was probably sent before the listener had set up its traps.)
        # So kill it again. We have moved on.
        kill_listener(:QUIT, listener)
      end
    end

    # Private: Spin up a new listener.
    #
    # The old one will be killed when the new one is ready for workers.
    def prepare_new_listener
      if @listeners.last_good
        # The last good listener is still running because we got another
        # HUP before the new listener finished booting.
        # Keep the last_good_listener (where all the workers are) and
        # kill the booting current_listener. We'll start a new one.
        kill_listener(:QUIT, @listeners.current)
        # Indicate to `start_listener` that it should start a new
        # listener.
        @listeners.clear_current!
      else
        @listeners.cycle_current
      end
    end

    def kill_listener(signal, listener)
      listener&.kill(signal)
    end

    def kill_all_listeners(signal)
      @listeners.each do |l|
        l.kill(signal)
      end
    end

    def wait_for_workers
      reap_all_listeners
    end

    def reap_all_listeners(waitpid_flags = 0)
      until @listeners.empty?
        begin
          lpid, status = Process.waitpid2(-1, waitpid_flags)
          return unless lpid

          log "Listener exited #{status}"

          if @listeners.current_pid == lpid
            @listener_backoff.died
            @listeners.clear_current!
          end

          if @listeners.last_good_pid == lpid
            @listeners.clear_last_good!
          end

          if dead_listener = @listeners.delete(lpid)
            listener_status dead_listener, "stop"
            dead_listener.dispose
          end

          write_procline
        rescue Errno::ECHILD
          return
        end
      end
    end

    SIGNALS = [:HUP, :INT, :USR1, :USR2, :CONT, :TERM, :QUIT].freeze
    OPTIONAL_SIGNALS = [:INFO].freeze
    OTHER_SIGNALS = [:CHLD, "EXIT"].freeze
    TRAPS = SIGNALS + OPTIONAL_SIGNALS + OTHER_SIGNALS

    SIGNAL_QUEUE = [] # rubocop: disable Style/MutableConstant

    def install_signal_handlers
      trap(:CHLD) { awake }
      SIGNALS.each { |signal| trap(signal) { SIGNAL_QUEUE << signal; awake } }
      OPTIONAL_SIGNALS.each { |signal| trap(signal) { SIGNAL_QUEUE << signal; awake } rescue nil }
    end

    def report_unexpected_exits
      trap("EXIT") do
        log("EXIT #{$!.inspect}")
        $!&.backtrace&.each do |line|
          log(line)
        end
      end
    end

    def no_more_unexpected_exits
      trap("EXIT", "DEFAULT")
    end

    def yawn(duration)
      super(duration, @listeners.map { |l| l.read_pipe })
    end

    def write_procline
      $0 = "#{procline_version} master [gen #{@state.listeners_created}] [#{@listeners.size} running] #{ARGV.join(' ')}"
    end

    def listener_status(listener, status)
      if listener&.pid
        status_message("listener", listener.pid, status)
      end
    end

    def worker_status(pid, status)
      status_message("worker", pid, status)
    end

    def status_message(type, pid, status)
      @status_pipe&.write("#{type},#{pid},#{status}\n")
    end
  end
end
