require "spec_helper"
require "resqued/sleepy"

describe Resqued::Sleepy do
  include Resqued::Sleepy

  it "sleeps" do
    expect { yawn(0.2) }.to run_for(0.2)
  end

  it "wakes on `awake`" do
    Thread.new { sleep 0.1; awake }
    expect { yawn(2.0) }.to run_for(0.1)
  end

  it "wakes on IO" do
    rd, wr = IO.pipe
    Thread.new { sleep 0.1; wr.write(".") }
    expect { yawn(2.0, rd) }.to run_for(0.1)
  end

  it "does not sleep if duration is 0" do
    expect { yawn(-0.000001) }.to run_for(0.0)
  end

  it "does not sleep if duration is negative" do
    expect { yawn(0) }.to run_for(0.0)
  end

  it "sleeps if io is nil" do
    expect { yawn(0.5, nil) }.to run_for(0.5)
  end
end
