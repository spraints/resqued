module Resqorn
  class Backoff
    def initialize(options = {})
      @time = options.fetch(:time) { Time }
    end

    # Public: Tell backoff that the thing we might want to back off from just started.
    def started
      check!
      @backoff_duration = @backing_off ? [@backoff_duration * 2, 64.0].min : 1.0
      @last_started_at = now
      @backing_off = @next_start_at = nil
    end

    # Public: Check if we should wait before starting again.
    def wait?
      ! ok?
    end

    # Public: Check if we are ok to start (i.e. we don't need to back off).
    def ok?
      check!
      how_long?.nil?
    end

    # Public: How much longer until `ok?` will be true?
    def how_long?
      check!
      next_start_at > now ? next_start_at - now : nil
    end

    private

    # Private: Check the current state.
    def check!
      @backing_off ||= next_start_at > now
    end

    # Private: Get the time when we can start again.
    def next_start_at
      @next_start_at ||= (@last_started_at && @backoff_duration) ? (@last_started_at + @backoff_duration) : now
    end

    # Private.
    def now
      @time.now
    end
  end
end
