require "spec_helper"
require "timeout"

describe "quit-and-wait gracefully stops resqued" do
  include ResquedIntegrationHelpers

  it do
    pidfile = File.join(SPEC_TEMPDIR, "graceful.pid")

    start_resqued(pidfile: pidfile)
    expect_running listener: "listener #1"

    # Make sure the process gets cleaned up.
    Thread.new do
      begin
        loop do
          Process.wait(@pid)
        end
      rescue Errno::ECHILD
        # ok!
      end
    end

    Timeout.timeout(15) do
      expect(system(resqued_path, "quit-and-wait", pidfile, "--grace-period", "10")).to be true
    end

    expect_not_running
  end

  after do
    begin
      Process.kill(:QUIT, @pid) if @pid
    rescue Errno::ESRCH
    end
  end
end
