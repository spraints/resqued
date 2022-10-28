require "resqued/config/after_fork"
require "resqued/config/before_fork"
require "resqued/config/after_exit"
require "resqued/config/worker"

module Resqued
  module Config
    # Public: Build a new ConfigFile instance.
    #
    # Resqued::Config is a module because the evaluators say so, so this `new` is a factory for another class.
    def self.new(paths)
      Configuration.new(paths)
    end

    # Does the things that the config file says to do.
    class Configuration
      def initialize(config_paths)
        @config_data = config_paths.map { |path| { content: File.read(path), path: path } }
      end

      # Public: Performs the `before_fork` action from the config.
      def before_fork(resqued)
        Resqued::Config::BeforeFork.new(resqued: resqued).apply_all(@config_data)
      end

      # Public: Performs the `after_fork` action from the config.
      def after_fork(worker)
        Resqued::Config::AfterFork.new(worker: worker).apply_all(@config_data)
      end

      # Public: Perform the `after_exit` action from the config.
      def after_exit(worker_summary)
        Resqued::Config::AfterExit.new(worker_summary: worker_summary).apply_all(@config_data)
      end

      # Public: Builds the workers specified in the config.
      def build_workers
        Resqued::Config::Worker.new(config: self).apply_all(@config_data)
      end
    end
  end
end
