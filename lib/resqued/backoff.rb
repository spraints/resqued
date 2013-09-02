module Resqued
  class Backoff
    def initialize(options = {})
      @time = options.fetch(:time) { Time }
      @min  = options.fetch(:min) { 1.0 }
      @max  = options.fetch(:max) { 16.0 }
      @backoff_duration = @min
    end

    # Public: Tell backoff that the thing we might want to back off from just started.
    def started
      @last_started_at = now
      @backoff_duration = @min if @last_event == :start
      @last_event = :start
    end

    # Public: Tell backoff that the thing unexpectedly died.
    def died
      @backoff_duration = @backoff_duration ? [@backoff_duration * 2.0, @max].min : @min
      @last_event = :died
    end

    # Public: Check if we should wait before starting again.
    def wait?
      @last_started_at && next_start_at > now
    end

    # Public: How much longer until `wait?` will be false?
    def how_long?
      wait? ? next_start_at - now : nil
    end

    private

    # Private: The next time when you're allowed to start a process.
    def next_start_at
      @last_started_at && @backoff_duration ? @last_started_at + @backoff_duration : now
    end

    # Private.
    def now
      @time.now
    end
  end
end
