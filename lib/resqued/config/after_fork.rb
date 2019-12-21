require "resqued/config/base"

module Resqued
  module Config
    # A config handler that executes the `after_fork` block.
    #
    #     after_fork do |resque_worker|
    #       # Runs in each worker.
    #     end
    class AfterFork < Base
      # Public.
      def initialize(options = {})
        @resque_worker = options.fetch(:worker)
      end

      # DSL: execute the `after_fork` block.
      def after_fork
        yield @resque_worker
      end
    end
  end
end
