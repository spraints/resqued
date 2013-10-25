require 'spec_helper'
require 'resqued/test_case'

describe Resqued::TestCase do
  let(:test_case) { Object.new.extend(the_module) }
  before { mock_redis.start ; ENV['RESQUED_TEST_REDIS_PORT'] = mock_redis.port.to_s }
  after  { mock_redis.stop  }
  let(:mock_redis) { MockRedisServer.new }

  shared_examples_for 'assert_resqued' do
    it('starts resqued')             { expect { test_case.assert_resqued 'spec/fixtures/test_case_environment.rb', 'spec/fixtures/test_case_clean.rb'              }.not_to raise_error }
    it('detects before_fork errors') { expect { test_case.assert_resqued 'spec/fixtures/test_case_environment.rb', 'spec/fixtures/test_case_before_fork_raises.rb' }.to     raise_error }
    it('ignores after_fork errors')  { expect { test_case.assert_resqued 'spec/fixtures/test_case_environment.rb', 'spec/fixtures/test_case_after_fork_raises.rb'  }.not_to raise_error }
    it('ignores worker absence')     { expect { test_case.assert_resqued 'spec/fixtures/test_case_environment.rb', 'spec/fixtures/test_case_no_workers.rb'         }.not_to raise_error }
    it('checks for workers')         { expect { test_case.assert_resqued 'spec/fixtures/test_case_environment.rb', 'spec/fixtures/test_case_clean.rb',             :expect_workers => true }.not_to raise_error }
    it('detects after_fork errors')  { expect { test_case.assert_resqued 'spec/fixtures/test_case_environment.rb', 'spec/fixtures/test_case_after_fork_raises.rb', :expect_workers => true }.to raise_error }
    it('detects worker absence')     { expect { test_case.assert_resqued 'spec/fixtures/test_case_environment.rb', 'spec/fixtures/test_case_no_workers.rb',        :expect_workers => true }.to raise_error }
  end

  context 'ForkToStart' do
    let(:the_module) { described_class::ForkToStart }
    it_behaves_like 'assert_resqued'
  end

  context 'ForkListener' do
    let(:the_module) { described_class::ForkListener }
    it_behaves_like 'assert_resqued'
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
