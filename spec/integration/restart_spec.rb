require "spec_helper"

describe "Resqued can restart" do
  include ResquedIntegrationHelpers

  it "expect to be able to restart" do
    start_resqued
    expect_running listener: "listener #1"
    restart_resqued
    expect_running listener: "listener #2"
    stop_resqued
    expect_not_running
  end

  after do
    begin
      Process.kill(:QUIT, @pid) if @pid
    rescue Errno::ESRCH
    end
  end
end
