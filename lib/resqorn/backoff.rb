module Resqorn
  class Backoff
    def initialize(options = {})
      @time = options.fetch(:time) { Time }
    end

    # Public: Tell backoff that the thing we might want to back off from just started.
    def started
      @last_started_at = now
      @backoff_duration = @backoff_duration ? [@backoff_duration * 2.0, 64.0].min : 1.0
    end

    def finished
      @backoff_duration = nil if ok?
    end

    # Public: Check if we should wait before starting again.
    def wait?
      @last_started_at && next_start_at > now
    end

    # Public: Check if we are ok to start (i.e. we don't need to back off).
    def ok?
      ! wait?
    end

    # Public: How much longer until `ok?` will be true?
    def how_long?
      ok? ? nil : next_start_at - now
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
