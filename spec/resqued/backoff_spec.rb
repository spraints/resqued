require 'spec_helper'

require 'resqued/backoff'

describe Resqued::Backoff do
  let(:backoff) { described_class.new }

  it 'can start on the first try' do
    expect(backoff.ok?).to be_true
  end

  it 'has no waiting at first' do
    expect(backoff.how_long?).to be_nil
  end

  context 'after one quick exit' do
    before { 1.times { backoff.started ; backoff.finished } }
    it { expect(backoff.ok?).to be_false }
    it { expect(backoff.how_long?).to be_close_to(1.0) }
  end

  context 'after two quick starts' do
    before { 2.times { backoff.started ; backoff.finished } }
    it { expect(backoff.ok?).to be_false }
    it { expect(backoff.how_long?).to be_close_to(2.0) }
  end

  context 'after five quick starts' do
    before { 6.times { backoff.started ; backoff.finished } }
    it { expect(backoff.ok?).to be_false }
    it { expect(backoff.how_long?).to be_close_to(32.0) }
  end

  context 'after six quick starts' do
    before { 7.times { backoff.started ; backoff.finished } }
    it { expect(backoff.ok?).to be_false }
    it { expect(backoff.how_long?).to be_close_to(64.0) }
  end

  context 'does not wait longer than 64s' do
    before { 8.times { backoff.started ; backoff.finished } }
    it { expect(backoff.ok?).to be_false }
    it { expect(backoff.how_long?).to be_close_to(64.0) }
  end

  context 'if the restarts were far enough apart' do
    let(:backoff) { backoff = described_class.new(:time => mock_time) }
    let(:mock_time) { double('Time').tap { |t| t.stub(:now) { @time_now } } }
    before do
      @time_now = Time.now
      3.times { backoff.started ; backoff.finished }
      expect(backoff.how_long?).to be_close_to(4.0)
      backoff.started
      # These should not affect anything.
      backoff.ok? ; backoff.wait? ; backoff.how_long?
      @time_now = @time_now + 8.01
      backoff.finished
      # We can start, because the child ran long enough.
      expect(backoff.ok?).to be_true
      # This time, we ran longer than the newly-reset backoff duration (1.0s).
      backoff.started
      @time_now = @time_now + 1.01
      backoff.finished
    end
    it { expect(backoff.ok?).to be_true }
    it { expect(backoff.how_long?).to be_nil }
  end

  def be_close_to(x)
    be_within(0.005).of(x)
  end
end
