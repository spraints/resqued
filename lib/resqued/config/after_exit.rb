require "resqued/config/base"

module Resqued
  module Config
    # A config handler that executes the `after_exit` block.
    #
    #     after_exit do |worker_summary|
    #       # Runs in each listener.
    #     end
    class AfterExit < Base
      # Public.
      def initialize(options = {})
        @worker_summary = options.fetch(:worker_summary)
      end

      # DSL: execute the `after_exit` block.
      def after_exit
        yield @worker_summary
      end
    end
  end
end
