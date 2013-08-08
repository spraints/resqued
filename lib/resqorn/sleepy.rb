require 'fcntl'
require 'kgio'

module Resqorn
  module Sleepy
    def self_pipe
      @self_pipe ||= Kgio::Pipe.new.each { |io| io.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC) }
    end

    def yawn(duration, *inputs)
      inputs = [self_pipe[0]] + [inputs].flatten.compact
      IO.select(inputs, nil, nil, duration) or return
      self_pipe[0].kgio_tryread(11)
    end

    def awake
      self_pipe[1].kgio_trywrite('.')
    end
  end
end
