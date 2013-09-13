require 'spec_helper'
require 'resqued/config/worker'

describe Resqued::Config::Worker do
  # Create a bunch of Resqued::Worker objects from
  #
  #    worker 'one'
  #    worker 'two', 'three', :interval => 2
  #    worker # assumes '*' as the queue
  #    worker_pool 10
  #    queue 'four', :percent => 20
  #    queue 'five', :count => 5
  #    queue 'six', '40%'
  #    queue 'seven', 3
  #    queue '*'
  #
  # ignore calls to any other top-level method.

  let(:evaluator) { described_class.new(:worker_class => FakeWorker) }
  let(:result) { evaluator.apply(config) }
  module FakeWorker
    def self.new(options)
      options
    end
  end

  context 'individual' do
    let(:config) { <<-END_CONFIG }
      before_fork { }
      after_fork { }
      2.times { worker 'a' }
      worker 'b'
      worker 'c', 'd'
      worker 'd', 'c', :interval => 3
      worker
      after_fork { } # So that we don't rely on `workers`'s result falling through.
    END_CONFIG
    it { expect(result.size).to eq(6) }
    it { expect(result[0]).to eq(:queues => ['a']) }
    it { expect(result[1]).to eq(:queues => ['a']) }
    it { expect(result[2]).to eq(:queues => ['b']) }
    it { expect(result[3]).to eq(:queues => ['c', 'd']) }
    it { expect(result[4]).to eq(:queues => ['d', 'c'], :interval => 3) }
    it { expect(result[5]).to eq(:queues => ['*']) }
  end

  context 'concise pool' do
    let(:config) { <<-END_CONFIG }
      worker_pool 2, 'a', 'b', 'c', :interval => 1
    END_CONFIG
    it { expect(result).to eq([
      { :queues => ['a', 'b', 'c'], :interval => 1 },
      { :queues => ['a', 'b', 'c'], :interval => 1 },
    ]) }
  end

  context 'pool (hash for concurrency)' do
    let(:config) { <<-END_CONFIG }
      before_fork { }
      after_fork { }
      worker_pool 20, :interval => 1
      queue 'a', :percent => 20
      queue 'b', :count => 10
      queue 'c'
      after_fork { } # So that we don't rely on `worker_pool`'s result falling through.
    END_CONFIG
    it { expect(result.size).to eq(20) }
    it { expect(result[0]).to eq(:queues => ['a', 'b', 'c'], :interval => 1) }
    it { expect(result[3]).to eq(:queues => ['a', 'b', 'c'], :interval => 1) }
    it { expect(result[4]).to eq(:queues => ['b', 'c'], :interval => 1) }
    it { expect(result[9]).to eq(:queues => ['b', 'c'], :interval => 1) }
    it { expect(result[10]).to eq(:queues => ['c'], :interval => 1) }
    it { expect(result[19]).to eq(:queues => ['c'], :interval => 1) }
  end

  context 'pool (value for concurrency)' do
    let(:config) { <<-END_CONFIG }
      before_fork { }
      after_fork { }
      worker_pool 20, :interval => 1
      queue 'a', '20%'
      queue 'b', 10
      queue 'c'
      after_fork { } # So that we don't rely on `worker_pool`'s result falling through.
    END_CONFIG
    it { expect(result.size).to eq(20) }
    it { expect(result[0]).to eq(:queues => ['a', 'b', 'c'], :interval => 1) }
    it { expect(result[3]).to eq(:queues => ['a', 'b', 'c'], :interval => 1) }
    it { expect(result[4]).to eq(:queues => ['b', 'c'], :interval => 1) }
    it { expect(result[9]).to eq(:queues => ['b', 'c'], :interval => 1) }
    it { expect(result[10]).to eq(:queues => ['c'], :interval => 1) }
    it { expect(result[19]).to eq(:queues => ['c'], :interval => 1) }
  end

  context 'pool, with implied queue' do
    let(:config) { <<-END_CONFIG }
      before_fork { }
      after_fork { }
      worker_pool 20
      after_fork { } # So that we don't rely on `worker_pool`'s result falling through.
    END_CONFIG
    it { expect(result.size).to eq(20) }
    it { expect(result[0]).to eq(:queues => ['*']) }
    it { expect(result[19]).to eq(:queues => ['*']) }
  end

  context 'pool, with fewer queues than workers' do
    let(:config) { <<-END_CONFIG }
      before_fork { }
      after_fork { }
      worker_pool 20
      queue 'a', 10
      after_fork { } # So that we don't rely on `worker_pool`'s result falling through.
    END_CONFIG
    it { expect(result.size).to eq(20) }
    it { expect(result[0]).to eq(:queues => ['a']) }
    it { expect(result[9]).to eq(:queues => ['a']) }
    it { expect(result[10]).to eq(:queues => ['*']) }
    it { expect(result[19]).to eq(:queues => ['*']) }
  end

  context 'pool, with more queues than workers' do
    let(:config) { <<-END_CONFIG }
      before_fork { }
      after_fork { }
      worker_pool 20
      queue 'a', 30
      after_fork { } # So that we don't rely on `worker_pool`'s result falling through.
    END_CONFIG
    it { expect(result.size).to eq(20) }
  end

  context 'multiple worker configs' do
    let(:config) { <<-END_CONFIG }
      worker 'one'
      worker 'two'
      worker_pool 2
    END_CONFIG
    it { expect(result.size).to eq(4) }
    it { expect(result[0]).to eq(:queues => ['one']) }
    it { expect(result[1]).to eq(:queues => ['two']) }
    it { expect(result[2]).to eq(:queues => ['*']) }
    it { expect(result[3]).to eq(:queues => ['*']) }
  end

  context 'with default options' do
    let(:evaluator) { described_class.new(:worker_class => FakeWorker, :config => 'something') }
    let(:config) { <<-END_CONFIG }
      worker 'a', :interval => 1
    END_CONFIG
    it { expect(result[0]).to eq(:queues => ['a'], :interval => 1, :config => 'something') }
  end
end
