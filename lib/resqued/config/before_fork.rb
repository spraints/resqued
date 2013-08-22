require 'resqued/config/base'

module Resqued
  module Config
    class BeforeFork < Base
      def before_fork
        yield
      end
    end
  end
end
