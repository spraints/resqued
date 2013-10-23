require 'spec_helper'
require 'resqued/test_case'

describe Resqued::TestCase do
  let(:test_case) { Object.new.extend(the_module) }
  before { mock_redis.start ; ENV['RESQUED_TEST_REDIS_PORT'] = mock_redis.port.to_s }
  after  { mock_redis.stop  }
  let(:mock_redis) { MockRedisServer.new }

  context 'ForkToStart' do
    let(:the_module) { described_class::ForkToStart }
    it { expect { test_case.assert_resqued 'spec/fixtures/test_case_environment.rb', 'spec/fixtures/test_case_clean.rb'              }.not_to raise_error }
    it { expect { test_case.assert_resqued 'spec/fixtures/test_case_environment.rb', 'spec/fixtures/test_case_before_fork_raises.rb' }.to     raise_error }
    it { expect { test_case.assert_resqued 'spec/fixtures/test_case_environment.rb', 'spec/fixtures/test_case_after_fork_raises.rb'  }.not_to raise_error }
    it { expect { test_case.assert_resqued 'spec/fixtures/test_case_environment.rb', 'spec/fixtures/test_case_no_workers.rb'         }.not_to raise_error }
    it { expect { test_case.assert_resqued 'spec/fixtures/test_case_environment.rb', 'spec/fixtures/test_case_clean.rb',             :expect_workers => true }.not_to raise_error }
    it { expect { test_case.assert_resqued 'spec/fixtures/test_case_environment.rb', 'spec/fixtures/test_case_after_fork_raises.rb', :expect_workers => true }.to raise_error }
    it { expect { test_case.assert_resqued 'spec/fixtures/test_case_environment.rb', 'spec/fixtures/test_case_no_workers.rb',        :expect_workers => true }.to raise_error }
  end
end

class MockRedisServer
  def start
    return if @server
    require 'socket'
    @server = TCPServer.new(0)
  end

  def stop
    return unless @server
    @server.close
  ensure
    @server = nil
  end

  def port
    @server && @server.addr[1]
  end
end
