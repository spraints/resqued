require 'resqued/config/base'

module Resqued
  module Config
    class AfterFork < Base
      def initialize(options = {})
        @resque_worker = options.fetch(:worker)
      end

      def after_fork
        yield @resque_worker
      end
    end
  end
end
