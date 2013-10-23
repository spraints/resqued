require 'spec_helper'
require 'resqued/test_case'

describe Resqued::TestCase do
  let(:test_case) { Object.new.extend(the_module) }
  before { mock_redis.start ; ENV['RESQUED_TEST_REDIS_PORT'] = mock_redis.port }
  after  { mock_redis.stop  }
  let(:mock_redis) { MockRedisServer.new }

  context 'ForkToStart' do
    let(:the_module) { described_class::ForkToStart }
    it { test_case.assert_resqued 'spec/fixtures/test_case.rb' }
  end

  context 'CleanStartup' do
    let(:the_module) { described_class::CleanStartup }
    it { test_case.assert_resqued 'spec/fixtures/test_case.rb' }
  end
end

class MockRedisServer
  def start
  end

  def stop
  end

  attr_reader :port
end
