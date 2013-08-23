require 'spec_helper'
require 'resqued/config/after_fork'
require 'resqued/config/before_fork'

describe do
  before { evaluator.apply(config) }

  context 'after_fork' do
    # Run the after_fork block.
    #
    #    after_fork do |resque_worker|
    #      ActiveRecord::Base.establish_connection
    #    end
    #
    # ignore calls to any other top-level method.

    let(:config) { <<-END_CONFIG }
      before_fork { }
      worker('one')
      worker_pool(10)
      queue('*')

      after_fork do |worker|
        worker.token = :called
      end
    END_CONFIG

    let(:evaluator) { Resqued::Config::AfterFork.new(:worker => worker) }
    let(:worker) { FakeResqueWorker.new }

    it { expect(worker.token).to eq(:called) }
  end

  context 'before_fork' do
    # Run the before_fork block.
    #
    #    before_fork do
    #      require "./config/environment.rb"
    #      Rails.application.eager_load!
    #    end
    #
    # ignore calls to any other top-level method.

    let(:config) { <<-END_CONFIG }
      after_fork { |worker| }
      worker('one')
      worker_pool(10)
      queue('*')

      before_fork do
        $before_fork_called = true
      end
    END_CONFIG

    let(:evaluator) { $before_fork_called = false ; Resqued::Config::BeforeFork.new }

    it { expect($before_fork_called).to eq(true) }
  end
end

class FakeResqueWorker
  attr_accessor :token
end
