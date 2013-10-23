# This file includes example assertions for your resqued configuration.
#
#     assert_resqued 'config/resqued/environment.rb', 'config/resqued/pool-a.rb'
module Resqued
  module TestCase
    module ForkToStart
      # Public: Fork a process that spins up a Resqued::Master process directly.
      def assert_resqued(*configs)
        options = configs.last.is_a?(Hash) ? configs.pop : {}
        status = IO.pipe
        if pid = fork
          message = read_status_from_resqued(:pipe => status[0], :pid => pid)
          if message !~ /^listener,\d+,start$/
            fail "Expected listener to start, but received #{message.inspect}"
          end
          message = read_status_from_resqued(:pipe => status[0], :pid => pid)
          if message !~ /^listener,\d+,ready$/
            fail "Expected listener to be ready, but received #{message.inspect}"
          end
          if options[:expect_workers]
            worker_timeout = options.fetch(:worker_timeout, 5)
            start = Time.now
            workers_started = 0
            loop do
              elapsed = Time.now - start
              time_remaining = worker_timeout - elapsed
              break unless time_remaining > 0
              if message = read_status_from_resqued(:pipe => status[0], :pid => pid, :timeout => time_remaining)
                if message =~ /worker,\d+,start/
                  workers_started = workers_started + 1
                else
                  fail "Expected to see workers starting, instead saw #{message.inspect}"
                end
              end
            end
            if workers_started == 0
              fail "Expected at least one worker to start, but none did"
            end
          end
        else
          $0 = "resqued master for #{$0}"
          devnull = File.open('/dev/null', 'w')
          $stdout.reopen(devnull)
          $stderr.reopen(devnull)
          begin
            # This should match how `exe/resqued` starts the master process.
            require 'resqued'
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

      def read_status_from_resqued(options)
        status  = options.fetch(:pipe)
        pid     = options.fetch(:pid)
        timeout = options[:timeout]
        loop do
          if IO.select([status], nil, nil, timeout || 2)
            return status.readline.chomp
          elsif dead = Process.waitpid2(pid, Process::WNOHANG)
            fail "Resqued stopped too soon."
          elsif timeout
            return nil
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
