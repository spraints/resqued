module Resqued
  class Daemon
    def initialize(master)
      @master = master
    end

    # Public: daemonize and run the master process.
    def run
      rd, wr = IO.pipe
      if fork
        # grandparent
        wr.close
        begin
          master_pid = rd.readpartial(16).to_i
          puts "Started master: #{master_pid}" if ENV["DEBUG"]
          exit
        rescue EOFError
          puts "Master process failed to start!"
          exit! 1
        end
      elsif fork
        # parent
        Process.setsid
        exit
      else
        # master
        STDIN.reopen "/dev/null"
        STDOUT.reopen "/dev/null", "a"
        STDERR.reopen "/dev/null", "a"
        rd.close
        @master.run(wr)
      end
    end
  end
end
