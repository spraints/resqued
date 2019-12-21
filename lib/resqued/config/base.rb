require "resqued/config/dsl"

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

      # Public: Apply the configuration from several files.
      def apply_all(configs)
        configs.each do |config|
          with_current_path(config[:path]) do
            instance_eval(config[:content], config[:path])
          end
        end
        results
      end

      private

      # Private: The results of applying the config.
      def results
      end

      # Private: Set a base path for require_relative.
      def with_current_path(path)
        @current_path, old_current_path = path, @current_path
        yield
      ensure
        @current_path = old_current_path
      end

      # Private: Override require_relative to work around https://bugs.ruby-lang.org/issues/4487
      def require_relative(path)
        if @current_path
          require File.expand_path(path, File.dirname(@current_path))
        else
          super
        end
      end
    end
  end
end
