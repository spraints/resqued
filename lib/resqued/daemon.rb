module Resqued
  class Daemon
    def initialize(master)
      @master = master
    end

    # Public: daemonize and run the master process.
    def run
      rd, wr = IO.pipe
      fork do
        # parent
        Process.setsid
        fork do
          # master
          @master.run(wr)
        end
      end
      wr.close
      master_pid = rd.readpartial(16).to_i
      exit
    rescue EOFError
      puts "Master process failed to start!"
      exit! 1
    end
  end
end
