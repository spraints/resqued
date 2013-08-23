require 'resqued/config/dsl'

module Resqued
  module Config
    # Base class for config handlers.
    class Base
      # Implement the DSL on the config handler itself.
      include Dsl

      # Public: Apply the configuration in `str`.
      #
      # Currently, this is a simple wrapper around `instance_eval`.
      def apply(str, filename = "INLINE")
        instance_eval(str, filename)
        results
      end

      private

      # Private: The results of applying the config.
      def results
      end
    end
  end
end
