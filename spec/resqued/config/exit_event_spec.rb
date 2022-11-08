require "spec_helper"
require "resqued/worker"
require "resqued/config/after_exit"

describe do
  before { evaluator.apply(config) }

  context "after_exit" do
    # Run the after_exit block.
    #
    #    after_exit do |worker_summary|
    #      puts "#{worker_summary.alive_time_sec}"
    #    end
    #
    # ignore calls to any other top-level method.

    let(:config) { <<-END_CONFIG }
      worker('one')
      worker_pool(1)
      queue('*')

      after_exit do |worker_summary|
        $after_exit_called = true
        $worker_alive_time_sec = worker_summary.alive_time_sec
        $exit_status = worker_summary.process_status.exitstatus
      end
    END_CONFIG

    let(:evaluator) {
      # In ruby versions < 3, Process::Status evaluates $? regardless of what status is returned by
      # exitcode for a status created with Process::Status.allocate
      fork do
        exit!
      end
      _, status = Process.waitpid2
      Resqued::Config::AfterExit.new(worker_summary: Resqued::WorkerSummary.new(alive_time_sec: 1, process_status: status))
    }

    it { expect($after_exit_called).to eq(true) }
    it { expect($worker_alive_time_sec > 0).to eq(true) }
    it { expect($exit_status).to eq(0) }
  end
end

class FakeResqueWorker
  attr_accessor :token
end
