module Resqued
  module Config
    # Defines the DSL for resqued config files.
    #
    # Each subclass should override parts of the dsl that it cares about.
    module Dsl
      # Public: Override this to implement this part of the DSL.
      def before_fork(&block)
      end

      # Public: Override this to implement this part of the DSL.
      def workers(options = {}, &block)
      end

      # Public: Override this to implement this part of the DSL.
      def worker_pool(count, options = {}, &block)
      end

      # Public: Override this to implement this part of the DSL.
      def after_fork(&block)
      end
    end
  end
end
