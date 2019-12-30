require "resqued/config/base"

module Resqued
  module Config
    # A config handler that executes the `before_fork` block.
    #
    #     before_fork do
    #       # Runs once, before forking all the workers.
    #     end
    class BeforeFork < Base
      def initialize(options = {})
        @resqued = options.fetch(:resqued)
      end

      # DSL: Execute the `before_fork` block.
      def before_fork
        yield @resqued
      end
    end
  end
end
