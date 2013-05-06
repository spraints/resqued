require File.expand_path("../setup", __FILE__)
require "resqued"

# ResqueDaemon::Master unit tests.
class WorkerTest < MiniTest::Unit::TestCase
  def test_initialize
    worker = ResqueDaemon::Worker.new(1, ['test', 'blah'])
    assert_equal ['test', 'blah'], worker.queues
  end

  def test_running?
    worker = ResqueDaemon::Worker.new(1, ['test', 'blah'])
    assert !worker.running?
  end

  def test_reaped?
    worker = ResqueDaemon::Worker.new(1, ['test', 'blah'])
    assert !worker.reaped?
  end

  def test_pid?
    worker = ResqueDaemon::Worker.new(1, ['test', 'blah'])
    assert !worker.pid?
  end
end
