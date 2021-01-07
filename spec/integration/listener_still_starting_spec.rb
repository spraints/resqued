require "spec_helper"

describe "Listener still starting on SIGHUP" do
  include ResquedIntegrationHelpers

  it "expect master not to crash" do
    start_resqued config: <<-CONFIG
      before_fork do
        sleep 1
      end
    CONFIG
    expect_running listener: "listener #1"
    restart_resqued
    sleep 2
    expect_running listener: "listener #2"
  end

  after do
    begin
      Process.kill(:QUIT, @pid) if @pid
    rescue Errno::ESRCH
    end
  end
end
