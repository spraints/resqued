require "spec_helper"
require "timeout"

describe "Resqued master with an extra child process" do
  include ResquedPath

  # Starts resqued with an extra child process.
  def start_resqued_with_extra_child
    shim_path = File.expand_path("../support/extra-child-shim", File.dirname(__FILE__))

    config_path = File.join(SPEC_TEMPDIR, "config.rb")
    File.write(config_path, <<-CONFIG)
      before_fork { File.write(ENV["LISTENER_PIDFILE"], $$.to_s) }
    CONFIG

    logfile = File.join(SPEC_TEMPDIR, "resqued.log")
    File.write(logfile, "") # truncate it

    env = {
      "LISTENER_PIDFILE" => listener_pidfile,
      "EXTRA_CHILD_PIDFILE" => extra_child_pidfile,
    }

    pid = spawn(env, shim_path, resqued_path, "--logfile", logfile, config_path)
    sleep 2.0
    pid
  end

  let(:extra_child_pidfile) { File.join(SPEC_TEMPDIR, "extra-child.pid") }
  def extra_child_pid
    File.read(extra_child_pidfile).to_i
  end

  let(:listener_pidfile) { File.join(File.join(SPEC_TEMPDIR, "listener.pid")) }
  def listener_pid
    File.read(listener_pidfile).to_i
  end

  before do
    File.unlink(extra_child_pidfile) rescue nil
    File.unlink(listener_pidfile) rescue nil
    @resqued_pid = start_resqued_with_extra_child
  end

  after do
    kill_safely(:TERM) { @resqued_pid }
    kill_safely(:KILL) { extra_child_pid }
    sleep 0.1
    kill_safely(:KILL) { @resqued_pid }
  end

  it "doesn't exit when listener dies unexpectedly" do
    # Kill off the listener process.
    first_listener_pid = listener_pid
    Process.kill :QUIT, first_listener_pid
    # Let Resqued::Backoff decide it's OK to start the listener again.
    sleep 2.5
    # Resqued should start a new listener to replace the dead one.
    expect(listener_pid).not_to eq(first_listener_pid)
  end

  it "exits when listeners have all exited during shutdown" do
    # Do a normal shutdown.
    Process.kill :QUIT, @resqued_pid
    # Expect the resqued process to exit.
    expect(Timeout.timeout(5.0) { Process.waitpid(@resqued_pid) }).to eq(@resqued_pid)
  end

  it "doesn't crash when extra child exits" do
    # Kill off the extra child process. Resqued should wait on it, but not exit.
    Process.kill :KILL, extra_child_pid
    sleep 1.0
    # The resqued process should not have exited.
    expect(Process.waitpid(@resqued_pid, Process::WNOHANG)).to be_nil
    expect(Process.kill(0, @resqued_pid)).to eq(1)
  end

  def kill_safely(signal)
    return unless pid = yield

    Process.kill(signal, pid)
  rescue Errno::ESRCH, Errno::ENOENT
    # Process isn't there anymore, or pidfile isn't there. :+1:
  end
end
