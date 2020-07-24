module CustomMatchers
  # Examples:
  #     expect { sleep 0.5 }.to run_for(0.5).within(0.0001)
  def run_for(expected_duration)
    RunFor.new(expected_duration)
  end

  class RunFor
    def initialize(expected_duration)
      @expected_duration = expected_duration
      @epsilon = 0.01
    end

    def supports_block_expectations?
      true
    end

    def within(epsilon)
      @epsilon = epsilon
      self
    end

    def matches?(event_proc)
      start_time = Time.now
      event_proc.call
      @actual_duration = Time.now - start_time
      diff = (@actual_duration - @expected_duration).abs
      @epsilon >= diff
    end

    def failure_message
      "Expected block to run for #{@expected_duration} +/-#{@epsilon} seconds, but it ran for #{@actual_duration} seconds."
    end

    def failure_message_when_negated
      "Expected block not to run for #{@expected_duration} +/-#{@epsilon} seconds, but it ran for #{@actual_duration} seconds."
    end
  end
end

RSpec.configure do |config|
  config.include CustomMatchers
end
