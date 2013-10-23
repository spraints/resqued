require 'spec_helper'
require 'resqued/test_case'

describe Resqued::TestCase do
  let(:test_case) { Object.new.extend(the_module) }
  before { mock_redis.start ; ENV['RESQUED_TEST_REDIS_PORT'] = mock_redis.port }
  after  { mock_redis.stop  }
  let(:mock_redis) { MockRedisServer.new }

  context 'ForkToStart' do
    let(:the_module) { described_class::ForkToStart }
    it { expect { test_case.assert_resqued 'spec/fixtures/test_case_clean.rb'              }.not_to raise_error }
    it { expect { test_case.assert_resqued 'spec/fixtures/test_case_before_fork_raises.rb' }.to     raise_error }
    it { expect { test_case.assert_resqued 'spec/fixtures/test_case_after_fork_raises.rb'  }.not_to raise_error }
    it { expect { test_case.assert_resqued 'spec/fixtures/test_case_no_workers.rb'         }.not_to raise_error }
    #it { expect { test_case.assert_resqued 'spec/fixtures/test_case_after_fork_raises.rb', :expect_workers => true }.not_to raise_error }
    #it { expect { test_case.assert_resqued 'spec/fixtures/test_case_no_workers.rb', :expect_workers => true }.to raise_error }
  end

  context 'CleanStartup' do
    let(:the_module) { described_class::CleanStartup }
    pending { test_case.assert_resqued 'spec/fixtures/test_case.rb' }
  end
end

class MockRedisServer
  def start
  end

  def stop
  end

  attr_reader :port
end
