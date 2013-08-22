require 'spec_helper'
require 'resqued/config/worker'

describe Resqued::Config::Worker do
  # Create a bunch of Resqued::Worker objects from
  #
  #    workers do |x|
  #      x.work_on 'queue1'
  #      x.work_on 'queue2'
  #      x.work_on 'queue3', 'queue4'
  #      x.work_on '*'
  #    end
  #
  # and / or
  #
  #    worker_pool(20) do |x|
  #      x.queue 'low', '20%'
  #      x.queue 'normal', 10
  #      x.queue '*'
  #    end
  #
  # or
  #
  #     worker_pool(20) # implies all workers work all queues.
  #
  # ignore calls to any other top-level method.

  let(:evaluator) { described_class.new(:worker_class => FakeWorker) }
  let(:result) { evaluator.apply(config) }
  module FakeWorker
    def self.new(*args)
      args
    end
  end

  context 'literal' do
    let(:config) { <<-END_CONFIG }
      before_fork { }
      after_fork { }
      workers do |x|
        2.times { x.work_on 'a' }
        x.work_on 'b'
        x.work_on 'c', 'd'
        x.work_on 'd', 'c'
      end
      after_fork { } # So that we don't rely on `workers`'s result falling through.
    END_CONFIG
    it { expect(result.size).to eq(5) }
    it { expect(result[0]).to eq([['a'], {}]) }
    it { expect(result[1]).to eq([['a'], {}]) }
    it { expect(result[2]).to eq([['b'], {}]) }
    it { expect(result[3]).to eq([['c', 'd'], {}]) }
    it { expect(result[4]).to eq([['d', 'c'], {}]) }

    context 'options' do
      let(:config) { <<-END_CONFIG }
        before_fork { }
        after_fork { }
        workers(:all => 1, :other => :default) do |x|
          x.work_on 'defaults'
          x.work_on 'custom', :other => :custom, :thing => 1
        end
        after_fork { } # So that we don't rely on `workers`'s result falling through.
      END_CONFIG
      it { expect(result[0]).to eq([['defaults'], {:all => 1, :other => :default}]) }
      it { expect(result[1]).to eq([['custom'], {:all => 1, :other => :custom, :thing => 1}]) }
    end
  end

  context 'intent' do
    let(:config) { <<-END_CONFIG }
      before_fork { }
      after_fork { }
      worker_pool(20, :interval => 1) do |x|
        x.queue 'a', '20%'
        x.queue 'b', 10
        x.queue 'c'
      end
      after_fork { } # So that we don't rely on `worker_pool`'s result falling through.
    END_CONFIG
    it { expect(result.size).to eq(20) }
    it { expect(result[0]).to eq([['a', 'b', 'c'], {:interval => 1}]) }
    it { expect(result[3]).to eq([['a', 'b', 'c'], {:interval => 1}]) }
    it { expect(result[4]).to eq([['b', 'c'], {:interval => 1}]) }
    it { expect(result[9]).to eq([['b', 'c'], {:interval => 1}]) }
    it { expect(result[10]).to eq([['c'], {:interval => 1}]) }
    it { expect(result[19]).to eq([['c'], {:interval => 1}]) }
  end

  context 'intent, with implied queue' do
    let(:config) { <<-END_CONFIG }
      before_fork { }
      after_fork { }
      worker_pool(20)
      after_fork { } # So that we don't rely on `worker_pool`'s result falling through.
    END_CONFIG
    it { expect(result.size).to eq(20) }
    it { expect(result[0]).to eq([['*'], {}]) }
    it { expect(result[19]).to eq([['*'], {}]) }
  end

  context 'intent, with fewer queues than workers' do
    let(:config) { <<-END_CONFIG }
      before_fork { }
      after_fork { }
      worker_pool(20) do |x|
        x.queue 'a', 10
      end
      after_fork { } # So that we don't rely on `worker_pool`'s result falling through.
    END_CONFIG
    it { expect(result.size).to eq(10) }
  end

  context 'intent, with more queues than workers' do
    let(:config) { <<-END_CONFIG }
      before_fork { }
      after_fork { }
      worker_pool(20) do |x|
        x.queue 'a', 30
      end
      after_fork { } # So that we don't rely on `worker_pool`'s result falling through.
    END_CONFIG
    it { expect(result.size).to eq(20) }
  end
end
