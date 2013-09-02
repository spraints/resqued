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
        rd.close
        @master.run(wr)
      end
    end
  end
end
