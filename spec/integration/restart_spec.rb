require "spec_helper"

describe "Resqued can restart" do
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

  def expect_running(listener:)
    processes = list_processes
    expect(processes).to include(is_resqued_master)
    listeners = processes.select { |p| p[:ppid] == @pid }.map { |p| p[:args] }
    expect(listeners).to all(match(/#{listener}/)).and(satisfy { |l| l.size == 1 })
  end

  def expect_not_running
    processes = list_processes
    expect(processes).not_to include(is_resqued_master)
  end

  def start_resqued
    # Don't configure any workers. That way, we don't need to have redis running.
    config_path = File.join(SPEC_TEMPDIR, "config.rb")
    File.write(config_path, "")

    resqued_path = File.expand_path("../../gemfiles/bin/resqued", File.dirname(__FILE__))
    unless File.executable?(resqued_path)
      resqued_path = File.expand_path("../../bin/resqued", File.dirname(__FILE__))
    end

    logfile = File.join(SPEC_TEMPDIR, "resqued.log")
    File.write(logfile, "") # truncate it

    @pid = spawn resqued_path, "--logfile", logfile, config_path
    sleep 1.0
  end

  def restart_resqued
    Process.kill(:HUP, @pid)
    sleep 1.0
  end

  def stop_resqued
    Process.kill(:TERM, @pid)
  end

  def list_processes
    `ps axo pid,ppid,args`.lines.map { |line| pid, ppid, args = line.strip.split(/\s+/, 3); { pid: pid.to_i, ppid: ppid.to_i, args: args } }
  end

  def is_resqued_master
    satisfy { |p| p[:pid] == @pid && p[:args] =~ /resqued-/ }
  end
end
