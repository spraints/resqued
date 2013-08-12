module Resqorn
  class Backoff
    def initialize(options = {})
      @time = options.fetch(:time) { Time }
    end

    # Public: Tell backoff that the thing we might want to back off from just started.
    def started
      check!
      @backoff_duration = @backing_off ? [@backoff_duration * 2, 64.0].min : 1.0
      @last_started_at = @time.now
      @backing_off = false
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
      if @last_started_at && @backoff_duration
        answer = @backoff_duration - (@time.now - @last_started_at)
        if answer > 0.0
          answer
        else
          nil
        end
      else
        nil
      end
    end

    private

    # Private: Check the current state.
    def check!
      if @last_started_at && @backoff_duration && !@backing_off
        @backing_off = (@time.now - @last_started_at) < @backoff_duration
      end
    end
  end
end
