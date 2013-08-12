require 'spec_helper'

require 'resqorn/backoff'

describe Resqorn::Backoff do
  let(:backoff) { described_class.new }

  it 'can start on the first try' do
    expect(backoff.ok?).to be_true
  end

  context 'after one quick exit' do
    before { 1.times { backoff.started } }
    it { expect(backoff.ok?).to be_false }
    it { expect(backoff.how_long?).to be_within(0.001).of(1.0) }
  end

  context 'after two quick starts' do
    before { 2.times { backoff.started } }
    it { expect(backoff.ok?).to be_false }
    it { expect(backoff.how_long?).to be_within(0.001).of(2.0) }
  end

  context 'after five quick starts' do
    before { 6.times { backoff.started } }
    it { expect(backoff.ok?).to be_false }
    it { expect(backoff.how_long?).to be_within(0.001).of(32.0) }
  end

  context 'after six quick starts' do
    before { 7.times { backoff.started } }
    it { expect(backoff.ok?).to be_false }
    it { expect(backoff.how_long?).to be_within(0.001).of(64.0) }
  end

  context 'does not wait longer than 64s' do
    before { 8.times { backoff.started } }
    it { expect(backoff.ok?).to be_false }
    it { expect(backoff.how_long?).to be_within(0.001).of(64.0) }
  end

  context 'if the restarts were far enough apart' do
    let(:backoff) { backoff = described_class.new(:time => mock_time) }
    let(:mock_time) { double('Time').tap { |t| t.stub(:now) { @time_now } } }
    before do
      @time_now = Time.now
      backoff.started
      @time_now = @time_now + 31
    end
    it { expect(backoff.ok?).to be_true }
  end
end
