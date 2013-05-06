require File.expand_path("../setup", __FILE__)
require "resqued"

# ResqueDaemon::Master unit tests.
class MasterTest < MiniTest::Unit::TestCase
  def test_defaults_to_one_worker_process
    master = ResqueDaemon::Master.new
    assert_equal 1, master.worker_processes
  end

  def test_no_queues_consumes_all
    master = ResqueDaemon::Master.new
    assert_equal({ '*' => 1.0 }, master.queues)
  end

  def test_translating_percentage_concurrency_to_fixed_concurrency
    queues = { 'critical' => 1.0, 'high' => 0.5, 'low' => 0.01 }
    master = ResqueDaemon::Master.new(queues, :worker_processes => 100)
    assert_equal queues, master.queues

    expected_queues = [['critical', 100], ['high', 50], ['low', 1]]
    assert_equal expected_queues, master.fixed_concurrency_queues
  end

  def test_translating_fixed_concurrency_to_fixed_concurrency
    queues = { 'critical' => 100, 'high' => 50, 'low' => 1 }
    master = ResqueDaemon::Master.new(queues, :worker_processes => 100)
    assert_equal queues, master.queues

    expected_queues = [['critical', 100], ['high', 50], ['low', 1]]
    assert_equal expected_queues, master.fixed_concurrency_queues
  end

  def test_translating_nil_concurrency_to_fixed_concurrency
    queues = { 'critical' => nil }
    master = ResqueDaemon::Master.new(queues, :worker_processes => 100)
    assert_equal queues, master.queues

    expected_queues = [['critical', 100]]
    assert_equal expected_queues, master.fixed_concurrency_queues
  end

  def test_translating_over_max_concurrency_to_fixed_concurrency
    queues = { 'critical' => 110 }
    master = ResqueDaemon::Master.new(queues, :worker_processes => 100)
    assert_equal queues, master.queues

    expected_queues = [['critical', 100]]
    assert_equal expected_queues, master.fixed_concurrency_queues
  end

  def test_building_workers
    queues = { 'critical' => 2 }
    master = ResqueDaemon::Master.new(queues, :worker_processes => 5)
    master.build_workers
    assert_equal 5, master.workers.size
    5.times { |i| assert_equal i + 1, master.workers[i].number }
  end
end
