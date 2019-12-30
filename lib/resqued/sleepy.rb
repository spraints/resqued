require "fcntl"
require "kgio"

module Resqued
  module Sleepy
    # Public: Like sleep, but the sleep is interrupted if input is
    # detected on one of the provided IO objects, or if `awake` is
    # called (e.g. from a signal handler).
    def yawn(duration, *inputs)
      if duration > 0
        inputs = [self_pipe[0]] + [inputs].flatten.compact
        IO.select(inputs, nil, nil, duration) or return
        self_pipe[0].kgio_tryread(11)
      end
    end

    # Public: Break out of `yawn`.
    def awake
      self_pipe[1].kgio_trywrite(".")
    end

    # Private.
    def self_pipe
      @self_pipe ||= Kgio::Pipe.new.each { |io| io.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC) }
    end
  end
end
