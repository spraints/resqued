# This file includes example assertions for your resqued configuration.
#
#     assert_resqued 'config/resqued/environment.rb', 'config/resqued/pool-a.rb'
module Resqued
  module TestCase
    module ForkToStart
      # Public: Fork a process that spins up a Resqued::Master process directly.
      def assert_resqued(*configs)
        options = configs.last.is_a?(Hash) ? configs.pop : {}
        check_workers  = options.fetch(:expect_workers, false)
        worker_timeout = options.fetch(:worker_timeout, 5)
        resqued_bin    = options.fetch(:resqued_bin) { `which resqued || bundle exec which resqued`.chomp }
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
          if check_workers
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
          unless ENV['NOISY_RESQUED_TESTS']
            devnull = File.open('/dev/null', 'w')
            $stdout.reopen(devnull)
            $stderr.reopen(devnull)
          end
          begin
            # This should match how `exe/resqued` starts the master process.
            require 'resqued'
            Resqued::START_CTX['$0'] = resqued_bin
            Resqued::Master.new(:config_paths => configs, :status_pipe => status[1]).run
          rescue Object => e
            # oops
          end
          exit! # Do not make this look like a failing test.
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

    module ForkListener
      # Public: Fork a process and run the resqued listener.
      def assert_resqued(*configs)
        options = configs.last.is_a?(Hash) ? configs.pop : {}
        check_workers  = options.fetch(:expect_workers, false)
        worker_timeout = options.fetch(:worker_timeout, 5)
        status = IO.pipe
        if pid = fork
          message = read_status_from_resqued(:pipe => status[0], :pid => pid)
          if message != 'RUNNING'
            fail "Expected listener to say \"RUNNING\", but it said #{message.inspect}"
          end
          if check_workers
            start = Time.now
            message = read_status_from_resqued(:pipe => status[0], :pid => pid, :timeout => worker_timeout)
            if message !~ /^+,\d+,/
              fail "Expected to see workers starting, instead saw #{message.inspect}"
            end
            message = read_status_from_resqued(:pipd => status[0], :pid => pid, :timeout => 1)
            if message && message =~ /^-/
              fail "Expected no workers to exit, but saw #{message.inspect}"
            end
          end
        else
          $0 = "resqued listener for #{$0}"
          unless ENV['NOISY_RESQUED_TESTS']
            devnull = File.open('/dev/null', 'w')
            $stdout.reopen(devnull)
            $stderr.reopen(devnull)
          end
          begin
            # This should match how 'resqued listener' starts the listener process.
            require 'resqued/listener'
            Resqued::Listener.new(:config_paths => configs, :socket => status[1], :listener_id => 'test').run
          rescue Object => e
            # oops
          ensure
            status[1].close
          end
          exit! # Do not let this look like a failing test.
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
  end
end
