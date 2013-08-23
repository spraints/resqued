require 'resqued/config/after_fork'
require 'resqued/config/before_fork'
require 'resqued/config/worker'

module Resqued
  module Config
    def self.new(*args)
      ConfigFile.new(*args)
    end

    class ConfigFile
      def initialize(config_path)
        @path = config_path
        @contents = File.read(@path)
      end

      def before_fork
        Resqued::Config::BeforeFork.new.apply(@contents, @path)
      end

      def after_fork(worker)
        Resqued::Config::AfterFork.new(:worker => worker).apply(@contents, @path)
      end

      def build_workers
        Resqued::Config::Worker.new(:config => self).apply(@contents, @path)
      end
    end
  end
end
