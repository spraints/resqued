# This file includes example assertions for your resqued configuration.
#
#     assert_resqued 'config/resqued/environment.rb', 'config/resqued/pool-a.rb'
#
# This assertion ensures that resqued starts at least one worker.
module Resqued
  module TestCase
    module ForkToStart
      # Public: Fork a process that spins up a Resqued::Master process directly.
      def assert_resqued(*configs)
        status = IO.pipe
        if pid = fork
          message = read_status_from_resqued(status[0], pid)
          if message !~ /^listener,\d+,start$/
            fail "Expected listener to start, but received #{message.inspect}"
          end
          message = read_status_from_resqued(status[0], pid)
          if message !~ /^listener,\d+,ready$/
            fail "Expected listener to be ready, but received #{message.inspect}"
          end
        else
          $0 = "resqued master for #{$0}"
          begin
            # This should match how `exe/resqued` starts the master process.
            require 'resqued'
            Resqued::Logging.log_file = '/dev/null'
            Resqued::START_CTX['$0'] = Gem.loaded_specs['resqued'].bin_file('resqued')
            Resqued::Master.new(:config_paths => configs, :status_pipe => status[1]).run
          rescue Object => e
            # oops
          end
          exit!
        end
      ensure
        begin
          Process.kill :QUIT, pid
          Process.waitpid2(pid) if pid
        rescue Errno::ESRCH, Errno::ECHILD
          # already dead.
        end
      end

      def read_status_from_resqued(status, pid)
        loop do
          if IO.select([status], nil, nil, 3)
            return status.readline.chomp
          elsif dead = Process.waitpid2(pid, Process::WNOHANG)
            fail "Resqued stopped too soon."
          end
        end
      end
    end

    module CleanStartup
      # Public: Start a new process for resqued, wait for a worker to start.
      def assert_resqued(*configs)
        fail 'todo'
      end
    end
  end
end
